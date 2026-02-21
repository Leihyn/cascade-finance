// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/core/PositionManager.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

contract MarginEngineTest is Test {
    MarginEngine public marginEngine;
    PositionManager public pm;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address trader = address(0x1);

    uint256 constant INITIAL_BALANCE = 1_000_000e6;
    uint256 constant NOTIONAL = 100_000e6;
    uint256 constant MARGIN = 10_000e6;
    uint256 constant FIXED_RATE = 0.05e18; // 5%

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy rate oracle with mock source
        rateSource = new MockRateSource(0.05e18, 0.07e18);

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();

        // Deploy position manager (with fee recipient)
        pm = new PositionManager(address(usdc), 6, address(this));

        // Deploy margin engine
        marginEngine = new MarginEngine(address(pm), address(oracle));

        // Setup trader
        usdc.mint(trader, INITIAL_BALANCE);
        vm.prank(trader);
        usdc.approve(address(pm), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SetsCorrectValues() public view {
        assertEq(address(marginEngine.positionManager()), address(pm));
        assertEq(address(marginEngine.rateOracle()), address(oracle));
        assertEq(marginEngine.initialMarginRatio(), 0.10e18);
        assertEq(marginEngine.maintenanceMarginRatio(), 0.05e18);
        assertEq(marginEngine.liquidationThreshold(), 1e18);
        assertEq(marginEngine.maxLeverage(), 10e18);
    }

    /*//////////////////////////////////////////////////////////////
                       INITIAL MARGIN CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    function test_calculateInitialMargin_BaseCase() public view {
        // 100,000 notional * 10% = 10,000 base margin
        uint256 margin = marginEngine.calculateInitialMargin(NOTIONAL, 30);

        // Should be at least 10% of notional
        assertGe(margin, NOTIONAL * 10 / 100);
    }

    function test_calculateInitialMargin_LongerMaturityHigherMargin() public view {
        uint256 margin30 = marginEngine.calculateInitialMargin(NOTIONAL, 30);
        uint256 margin90 = marginEngine.calculateInitialMargin(NOTIONAL, 90);
        uint256 margin365 = marginEngine.calculateInitialMargin(NOTIONAL, 365);

        // Longer maturity should require more margin
        assertGe(margin90, margin30);
        assertGe(margin365, margin90);
    }

    function test_calculateInitialMargin_ScalesWithNotional() public view {
        uint256 margin1 = marginEngine.calculateInitialMargin(100_000e6, 90);
        uint256 margin2 = marginEngine.calculateInitialMargin(200_000e6, 90);

        // Double notional should approximately double margin
        assertApproxEqRel(margin2, margin1 * 2, 0.01e18);
    }

    /*//////////////////////////////////////////////////////////////
                     MAINTENANCE MARGIN CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    function test_calculateMaintenanceMargin_BaseCase() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 maintMargin = marginEngine.calculateMaintenanceMargin(posId);

        // Should be at least 5% of notional
        assertGe(maintMargin, NOTIONAL * 5 / 100);
    }

    function test_calculateMaintenanceMargin_IncreasesWithNegativePnL() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true, // Pay fixed
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Get initial maintenance margin
        uint256 initialMaint = marginEngine.calculateMaintenanceMargin(posId);

        // Move rate lower (causes loss for pay-fixed position)
        rateSource.setSupplyRate(0.02e18);
        oracle.updateRate();

        // Advance time to accumulate PnL
        vm.warp(block.timestamp + 30 days);

        // Maintenance margin should increase with negative PnL
        uint256 newMaint = marginEngine.calculateMaintenanceMargin(posId);
        assertGe(newMaint, initialMaint);
    }

    function test_calculateMaintenanceMargin_RevertIfNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(MarginEngine.PositionNotActive.selector, 999)
        );
        marginEngine.calculateMaintenanceMargin(999);
    }

    /*//////////////////////////////////////////////////////////////
                          HEALTH FACTOR
    //////////////////////////////////////////////////////////////*/

    function test_getHealthFactor_HealthyPosition() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 healthFactor = marginEngine.getHealthFactor(posId);

        // Initial position should be healthy (HF > 1)
        // With 10% margin and 5% maintenance, HF should be ~2
        assertGt(healthFactor, 1e18);
    }

    function test_getHealthFactor_DecreasesWithLoss() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true, // Pay fixed
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 initialHF = marginEngine.getHealthFactor(posId);

        // Set floating lower (loss for pay-fixed)
        rateSource.setSupplyRate(0.01e18);
        oracle.updateRate();

        // Advance time
        vm.warp(block.timestamp + 30 days);

        uint256 newHF = marginEngine.getHealthFactor(posId);
        assertLt(newHF, initialHF);
    }

    function test_getHealthFactor_IncreasesWithProfit() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true, // Pay fixed
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 initialHF = marginEngine.getHealthFactor(posId);

        // Set floating higher (profit for pay-fixed)
        rateSource.setSupplyRate(0.10e18);
        oracle.updateRate();

        // Advance time
        vm.warp(block.timestamp + 30 days);

        uint256 newHF = marginEngine.getHealthFactor(posId);
        assertGt(newHF, initialHF);
    }

    function test_getHealthFactor_ZeroForInactivePosition() public view {
        uint256 healthFactor = marginEngine.getHealthFactor(999);
        assertEq(healthFactor, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION CHECK
    //////////////////////////////////////////////////////////////*/

    function test_isLiquidatable_FalseForHealthyPosition() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        assertFalse(marginEngine.isLiquidatable(posId));
    }

    function test_isLiquidatable_TrueWhenUnderwater() public {
        // Create position with minimum margin (10%)
        uint256 minMargin = NOTIONAL * 10 / 100;

        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true, // Pay fixed 5%
            uint128(NOTIONAL),
            uint128(0.30e18), // 30% fixed rate - will suffer massive losses vs low floating
            365, // Long maturity
            uint128(minMargin)
        );

        // Set floating to 0.1% (massive loss for pay-fixed at 30%)
        rateSource.setSupplyRate(0.001e18);
        oracle.updateRate();

        // Advance nearly full year - loss of ~30% of notional
        vm.warp(block.timestamp + 330 days);

        // Check health factor before assertion for debugging
        uint256 hf = marginEngine.getHealthFactor(posId);

        // Position should be liquidatable (30% loss on notional exceeds 10% margin)
        assertTrue(marginEngine.isLiquidatable(posId), "Position should be liquidatable");
    }

    function test_isLiquidatable_FalseForInactivePosition() public view {
        assertFalse(marginEngine.isLiquidatable(999));
    }

    /*//////////////////////////////////////////////////////////////
                        MARGIN UTILIZATION
    //////////////////////////////////////////////////////////////*/

    function test_getMarginUtilization_HealthyPosition() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(MARGIN),
            90,
            uint128(MARGIN)
        );

        uint256 utilization = marginEngine.getMarginUtilization(posId);

        // Healthy position should have low utilization
        assertLt(utilization, 1e18);
    }

    function test_getMarginUtilization_IncreasesWithLoss() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 initialUtil = marginEngine.getMarginUtilization(posId);

        // Cause loss
        rateSource.setSupplyRate(0.01e18);
        oracle.updateRate();
        vm.warp(block.timestamp + 30 days);

        uint256 newUtil = marginEngine.getMarginUtilization(posId);
        assertGt(newUtil, initialUtil);
    }

    function test_getMarginUtilization_ZeroForInactive() public view {
        uint256 utilization = marginEngine.getMarginUtilization(999);
        assertEq(utilization, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        MAX NOTIONAL CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_calculateMaxNotional_ScalesWithMargin() public view {
        uint256 max1 = marginEngine.calculateMaxNotional(10_000e6, 90);
        uint256 max2 = marginEngine.calculateMaxNotional(20_000e6, 90);

        // Double margin should approximately double max notional
        assertApproxEqRel(max2, max1 * 2, 0.01e18);
    }

    function test_calculateMaxNotional_DecreasesWithMaturity() public view {
        uint256 max30 = marginEngine.calculateMaxNotional(MARGIN, 30);
        uint256 max365 = marginEngine.calculateMaxNotional(MARGIN, 365);

        // Longer maturity should allow less notional
        assertGt(max30, max365);
    }

    function test_calculateMaxNotional_RespectLeverageCap() public view {
        // With 10x max leverage and 10,000 margin, max notional should be 100,000
        uint256 maxNotional = marginEngine.calculateMaxNotional(MARGIN, 30);
        assertLe(maxNotional, MARGIN * 10);
    }

    /*//////////////////////////////////////////////////////////////
                          POSITION LEVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_getPositionLeverage_CorrectCalculation() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 leverage = marginEngine.getPositionLeverage(posId);

        // 100,000 notional / 10,000 margin = 10x leverage
        assertApproxEqRel(leverage, 10e18, 0.01e18);
    }

    function test_getPositionLeverage_IncreasesWithLoss() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 initialLev = marginEngine.getPositionLeverage(posId);

        // Cause loss
        rateSource.setSupplyRate(0.01e18);
        oracle.updateRate();
        vm.warp(block.timestamp + 30 days);

        uint256 newLev = marginEngine.getPositionLeverage(posId);
        assertGt(newLev, initialLev);
    }

    function test_getPositionLeverage_ZeroForInactive() public view {
        uint256 leverage = marginEngine.getPositionLeverage(999);
        assertEq(leverage, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          MARGIN BUFFER
    //////////////////////////////////////////////////////////////*/

    function test_getMarginBuffer_PositiveForHealthy() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        int256 buffer = marginEngine.getMarginBuffer(posId);

        // Healthy position should have positive buffer
        assertGt(buffer, 0);
    }

    function test_getMarginBuffer_DecreasesWithLoss() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        int256 initialBuffer = marginEngine.getMarginBuffer(posId);

        // Cause loss
        rateSource.setSupplyRate(0.01e18);
        oracle.updateRate();
        vm.warp(block.timestamp + 30 days);

        int256 newBuffer = marginEngine.getMarginBuffer(posId);
        assertLt(newBuffer, initialBuffer);
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_batchGetHealthFactors_MultiplePositions() public {
        vm.startPrank(trader);
        uint256 pos1 = pm.openPosition(true, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN));
        uint256 pos2 = pm.openPosition(false, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN));
        uint256 pos3 = pm.openPosition(true, uint128(NOTIONAL), uint128(0.08e18), 90, uint128(MARGIN));
        vm.stopPrank();

        uint256[] memory posIds = new uint256[](4);
        posIds[0] = pos1;
        posIds[1] = pos2;
        posIds[2] = pos3;
        posIds[3] = 999; // Non-existent

        uint256[] memory healthFactors = marginEngine.batchGetHealthFactors(posIds);

        assertEq(healthFactors.length, 4);
        assertGt(healthFactors[0], 0);
        assertGt(healthFactors[1], 0);
        assertGt(healthFactors[2], 0);
        assertEq(healthFactors[3], 0); // Non-existent
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setMarginParameters_Success() public {
        marginEngine.setMarginParameters(0.15e18, 0.08e18, 1.2e18);

        assertEq(marginEngine.initialMarginRatio(), 0.15e18);
        assertEq(marginEngine.maintenanceMarginRatio(), 0.08e18);
        assertEq(marginEngine.liquidationThreshold(), 1.2e18);
    }

    function test_setMarginParameters_RevertIfInvalidInitialRatio() public {
        vm.expectRevert(MarginEngine.InvalidRatio.selector);
        marginEngine.setMarginParameters(0, 0.05e18, 1e18);

        vm.expectRevert(MarginEngine.InvalidRatio.selector);
        marginEngine.setMarginParameters(1.1e18, 0.05e18, 1e18);
    }

    function test_setMarginParameters_RevertIfMaintenanceNotLessThanInitial() public {
        vm.expectRevert(MarginEngine.InvalidRatio.selector);
        marginEngine.setMarginParameters(0.10e18, 0.10e18, 1e18);

        vm.expectRevert(MarginEngine.InvalidRatio.selector);
        marginEngine.setMarginParameters(0.10e18, 0.15e18, 1e18);
    }

    function test_setMarginParameters_RevertIfInvalidThreshold() public {
        vm.expectRevert(MarginEngine.InvalidThreshold.selector);
        marginEngine.setMarginParameters(0.10e18, 0.05e18, 0);

        vm.expectRevert(MarginEngine.InvalidThreshold.selector);
        marginEngine.setMarginParameters(0.10e18, 0.05e18, 2.5e18);
    }

    function test_setMarginParameters_OnlyOwner() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        marginEngine.setMarginParameters(0.15e18, 0.08e18, 1.2e18);
    }

    function test_setMarginParameters_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MarginEngine.MarginParametersUpdated(0.15e18, 0.08e18, 1.2e18);

        marginEngine.setMarginParameters(0.15e18, 0.08e18, 1.2e18);
    }

    function test_setMaxLeverage_Success() public {
        marginEngine.setMaxLeverage(20e18);
        assertEq(marginEngine.maxLeverage(), 20e18);
    }

    function test_setMaxLeverage_RevertIfInvalid() public {
        vm.expectRevert(MarginEngine.InvalidLeverage.selector);
        marginEngine.setMaxLeverage(0);

        vm.expectRevert(MarginEngine.InvalidLeverage.selector);
        marginEngine.setMaxLeverage(101e18);
    }

    function test_setMaxLeverage_OnlyOwner() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        marginEngine.setMaxLeverage(20e18);
    }

    function test_setMaxLeverage_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MarginEngine.MaxLeverageUpdated(20e18);

        marginEngine.setMaxLeverage(20e18);
    }

    function test_setRateVolatilityFactor_Success() public {
        marginEngine.setRateVolatilityFactor(0.05e18);
        assertEq(marginEngine.rateVolatilityFactor(), 0.05e18);
    }

    function test_setRateVolatilityFactor_RevertIfTooHigh() public {
        vm.expectRevert(MarginEngine.InvalidRatio.selector);
        marginEngine.setRateVolatilityFactor(0.51e18);
    }

    function test_setRateVolatilityFactor_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MarginEngine.RateVolatilityFactorUpdated(0.05e18);

        marginEngine.setRateVolatilityFactor(0.05e18);
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_healthFactor_CorrelatesWithMargin(
        uint256 marginSeed
    ) public {
        uint256 testMargin = bound(marginSeed, NOTIONAL * 10 / 100, NOTIONAL * 50 / 100);

        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(testMargin)
        );

        uint256 healthFactor = marginEngine.getHealthFactor(posId);

        // Higher margin should mean higher health factor
        // With 5% maintenance, HF = margin / (notional * 0.05)
        uint256 expectedMinHF = testMargin * 1e18 / (NOTIONAL * 5 / 100);
        assertApproxEqRel(healthFactor, expectedMinHF, 0.05e18);
    }

    function testFuzz_leverage_InverseOfMarginRatio(
        uint256 marginSeed
    ) public {
        // Margin must be at least 10% of notional (initial margin requirement)
        uint256 testMargin = bound(marginSeed, NOTIONAL * 10 / 100, NOTIONAL * 50 / 100);

        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(testMargin)
        );

        uint256 leverage = marginEngine.getPositionLeverage(posId);
        uint256 expectedLeverage = NOTIONAL * 1e18 / testMargin;

        assertApproxEqRel(leverage, expectedLeverage, 0.05e18);
    }
}
