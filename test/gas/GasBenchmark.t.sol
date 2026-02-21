// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/risk/LiquidationEngine.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

/// @title GasBenchmark
/// @notice Comprehensive gas profiling for all protocol operations
contract GasBenchmark is Test {
    PositionManager public pm;
    SettlementEngine public settlement;
    MarginEngine public marginEngine;
    LiquidationEngine public liquidation;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address feeRecipient = makeAddr("feeRecipient");

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        rateSource = new MockRateSource(0.05e18, 0.07e18);

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();

        pm = new PositionManager(address(usdc), 6, feeRecipient);
        marginEngine = new MarginEngine(address(pm), address(oracle));
        settlement = new SettlementEngine(
            address(pm), address(oracle), 1 days, address(usdc), feeRecipient
        );
        liquidation = new LiquidationEngine(
            address(pm), address(marginEngine), address(usdc), feeRecipient
        );

        pm.setAuthorizedContract(address(settlement), true);
        pm.setAuthorizedContract(address(liquidation), true);

        usdc.mint(alice, 10_000_000e6);
        usdc.mint(bob, 10_000_000e6);
        usdc.mint(address(pm), 10_000_000e6);
        usdc.mint(address(liquidation), 10_000_000e6);

        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(pm), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                      POSITION MANAGER BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_openPosition_cold() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
    }

    function test_gas_openPosition_warm() public {
        // First position (cold storage)
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Second position (warm storage)
        vm.prank(alice);
        pm.openPosition(true, 50_000e6, 0.06e18, 180, 5_000e6);
    }

    function test_gas_openPosition_payFloating() public {
        vm.prank(alice);
        pm.openPosition(false, 100_000e6, 0.05e18, 90, 10_000e6);
    }

    function test_gas_addMargin() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(alice);
        pm.addMargin(posId, 5_000e6);
    }

    function test_gas_removeMargin() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 20_000e6);

        vm.prank(alice);
        pm.removeMargin(posId, 5_000e6);
    }

    function test_gas_batchOpenPositions_5() public {
        PositionManager.OpenPositionParams[] memory params = new PositionManager.OpenPositionParams[](5);

        for (uint256 i = 0; i < 5; i++) {
            params[i] = PositionManager.OpenPositionParams({
                isPayingFixed: true,
                notional: 100_000e6,
                fixedRate: 0.05e18,
                maturityDays: 90,
                margin: 10_000e6
            });
        }

        vm.prank(alice);
        pm.openMultiplePositions(params);
    }

    function test_gas_batchOpenPositions_10() public {
        PositionManager.OpenPositionParams[] memory params =
            new PositionManager.OpenPositionParams[](10);

        for (uint256 i = 0; i < 10; i++) {
            params[i] = PositionManager.OpenPositionParams({
                isPayingFixed: i % 2 == 0,
                notional: 100_000e6,
                fixedRate: 0.05e18,
                maturityDays: 90,
                margin: 10_000e6
            });
        }

        vm.prank(alice);
        pm.openMultiplePositions(params);
    }

    function test_gas_getPosition() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        pm.getPosition(posId);
    }

    function test_gas_tokenURI() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        pm.tokenURI(posId);
    }

    /*//////////////////////////////////////////////////////////////
                      SETTLEMENT ENGINE BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_settle_singlePosition() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.warp(block.timestamp + 1 days);
        rateSource.setSupplyRate(0.06e18);
        oracle.updateRate();

        settlement.settle(posId);
    }

    function test_gas_settle_positiveSettlement() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.04e18, 90, 10_000e6);

        // Rate goes up - positive for pay fixed
        vm.warp(block.timestamp + 1 days);
        rateSource.setSupplyRate(0.08e18);
        oracle.updateRate();

        settlement.settle(posId);
    }

    function test_gas_settle_negativeSettlement() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.06e18, 90, 10_000e6);

        // Rate goes down - negative for pay fixed
        vm.warp(block.timestamp + 1 days);
        rateSource.setSupplyRate(0.03e18);
        oracle.updateRate();

        settlement.settle(posId);
    }

    function test_gas_batchSettle_5positions() public {
        uint256[] memory posIds = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            posIds[i] = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        }

        vm.warp(block.timestamp + 1 days);
        oracle.updateRate();

        settlement.batchSettle(posIds);
    }

    function test_gas_batchSettle_10positions() public {
        uint256[] memory posIds = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(alice);
            posIds[i] = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        }

        vm.warp(block.timestamp + 1 days);
        oracle.updateRate();

        settlement.batchSettle(posIds);
    }

    function test_gas_closeMaturedPosition() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 30, 10_000e6);

        vm.warp(block.timestamp + 31 days);
        oracle.updateRate();

        settlement.closeMaturedPosition(posId);
    }

    function test_gas_getPendingSettlement() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.warp(block.timestamp + 1 days);
        rateSource.setSupplyRate(0.06e18);
        oracle.updateRate();

        settlement.getPendingSettlement(posId);
    }

    function test_gas_canSettle() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        settlement.canSettle(posId);
    }

    /*//////////////////////////////////////////////////////////////
                      MARGIN ENGINE BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_getHealthFactor() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        marginEngine.getHealthFactor(posId);
    }

    function test_gas_getHealthFactor_afterSettlement() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.warp(block.timestamp + 1 days);
        rateSource.setSupplyRate(0.06e18);
        oracle.updateRate();
        settlement.settle(posId);

        marginEngine.getHealthFactor(posId);
    }

    function test_gas_batchGetHealthFactors_10() public {
        uint256[] memory posIds = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(alice);
            posIds[i] = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        }

        marginEngine.batchGetHealthFactors(posIds);
    }

    function test_gas_batchGetHealthFactors_20() public {
        uint256[] memory posIds = new uint256[](20);

        for (uint256 i = 0; i < 20; i++) {
            vm.prank(alice);
            posIds[i] = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        }

        marginEngine.batchGetHealthFactors(posIds);
    }

    function test_gas_isLiquidatable() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        marginEngine.isLiquidatable(posId);
    }

    function test_gas_calculateInitialMargin() public view {
        marginEngine.calculateInitialMargin(100_000e6, 90);
    }

    function test_gas_calculateMaintenanceMargin() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        marginEngine.calculateMaintenanceMargin(posId);
    }

    function test_gas_getPositionLeverage() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        marginEngine.getPositionLeverage(posId);
    }

    function test_gas_getMarginUtilization() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        marginEngine.getMarginUtilization(posId);
    }

    /*//////////////////////////////////////////////////////////////
                      LIQUIDATION ENGINE BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_canLiquidate() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        liquidation.canLiquidate(posId);
    }

    function test_gas_previewLiquidation() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        liquidation.previewLiquidation(posId);
    }

    function test_gas_findLiquidatablePositions_50() public {
        // Create 50 positions
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(alice);
            pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        }

        liquidation.findLiquidatablePositions(0, 49);
    }

    function test_gas_findLiquidatablePositions_100() public {
        // Create 100 positions
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(alice);
            pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        }

        liquidation.findLiquidatablePositions(0, 99);
    }

    /*//////////////////////////////////////////////////////////////
                        RATE ORACLE BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_getCurrentRate_1source() public view {
        oracle.getCurrentRate();
    }

    function test_gas_updateRate() public {
        oracle.updateRate();
    }

    function test_gas_getFreshRate() public view {
        oracle.getFreshRate();
    }

    function test_gas_isStale() public view {
        oracle.isStale();
    }

    function test_gas_getTWAP_1hour() public {
        // Start at realistic timestamp to avoid underflow
        vm.warp(1 hours);
        oracle.updateRate();

        // Build observation history
        for (uint256 i = 0; i < 6; i++) {
            vm.warp(block.timestamp + 10 minutes);
            rateSource.setSupplyRate(0.05e18 + (i * 0.001e18));
            oracle.updateRate();
        }

        oracle.getTWAP(1 hours);
    }

    function test_gas_getTWAP_24hours() public {
        // Start at realistic timestamp to avoid underflow
        vm.warp(24 hours);
        oracle.updateRate();

        // Build observation history
        for (uint256 i = 0; i < 24; i++) {
            vm.warp(block.timestamp + 1 hours);
            rateSource.setSupplyRate(0.05e18 + (i * 0.001e18));
            oracle.updateRate();
        }

        oracle.getTWAP(24 hours);
    }

    /*//////////////////////////////////////////////////////////////
                     COMPLEX SCENARIO BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_fullLifecycle_openSettleClose() public {
        // Open
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 30, 10_000e6);

        // Settle multiple times
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 1 days);
            rateSource.setSupplyRate(0.05e18 + (i * 0.005e18));
            oracle.updateRate();

            if (settlement.canSettle(posId)) {
                settlement.settle(posId);
            }
        }

        // Close at maturity
        vm.warp(block.timestamp + 30 days);
        oracle.updateRate();
        settlement.closeMaturedPosition(posId);
    }

    function test_gas_multiUserScenario() public {
        // Alice opens position
        vm.prank(alice);
        uint256 alicePos = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Bob opens opposite position
        vm.prank(bob);
        uint256 bobPos = pm.openPosition(false, 100_000e6, 0.05e18, 90, 10_000e6);

        // Time passes, rates change
        vm.warp(block.timestamp + 1 days);
        rateSource.setSupplyRate(0.06e18);
        oracle.updateRate();

        // Both settle
        settlement.settle(alicePos);
        settlement.settle(bobPos);
    }
}
