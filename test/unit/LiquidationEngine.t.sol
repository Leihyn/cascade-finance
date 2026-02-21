// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/risk/LiquidationEngine.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/core/PositionManager.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

contract LiquidationEngineTest is Test {
    LiquidationEngine public liquidationEngine;
    MarginEngine public marginEngine;
    PositionManager public pm;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address trader = address(0x1);
    address liquidator = address(0x2);
    address feeRecipient = address(0x3);

    uint256 constant INITIAL_BALANCE = 1_000_000e6;
    uint256 constant NOTIONAL = 100_000e6;
    uint256 constant MARGIN = 10_000e6;
    uint256 constant FIXED_RATE = 0.05e18; // 5%

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy rate oracle
        rateSource = new MockRateSource(0.05e18, 0.07e18);
        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();

        // Deploy position manager (with fee recipient)
        pm = new PositionManager(address(usdc), 6, address(this));

        // Deploy margin engine
        marginEngine = new MarginEngine(address(pm), address(oracle));

        // Deploy liquidation engine
        liquidationEngine = new LiquidationEngine(
            address(pm),
            address(marginEngine),
            address(usdc),
            feeRecipient
        );

        // Authorize liquidation engine
        pm.setAuthorizedContract(address(liquidationEngine), true);

        // Setup traders
        usdc.mint(trader, INITIAL_BALANCE);
        usdc.mint(liquidator, INITIAL_BALANCE);
        usdc.mint(address(pm), 100_000e6); // Extra funds for payouts
        usdc.mint(address(liquidationEngine), 100_000e6); // Extra for liquidation rewards with bonus

        vm.prank(trader);
        usdc.approve(address(pm), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SetsCorrectValues() public view {
        assertEq(address(liquidationEngine.positionManager()), address(pm));
        assertEq(address(liquidationEngine.marginEngine()), address(marginEngine));
        assertEq(address(liquidationEngine.collateralToken()), address(usdc));
        assertEq(liquidationEngine.protocolFeeRecipient(), feeRecipient);
        assertEq(liquidationEngine.liquidationBonus(), 0.05e18);
        assertEq(liquidationEngine.protocolFee(), 0.02e18);
        assertEq(liquidationEngine.maxLiquidationRatio(), 0.50e18);
    }

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_liquidate_Success() public {
        // Create liquidatable position
        uint256 posId = _createLiquidatablePosition();

        // Record balances before
        uint256 liquidatorBefore = usdc.balanceOf(liquidator);

        // Liquidate
        vm.prank(liquidator);
        (uint256 marginSeized, uint256 reward) = liquidationEngine.liquidate(posId);

        // Verify liquidator received reward
        uint256 liquidatorAfter = usdc.balanceOf(liquidator);
        assertEq(liquidatorAfter - liquidatorBefore, reward);
        assertGt(marginSeized, 0);
        assertGt(reward, 0);
    }

    function test_liquidate_UpdatesStats() public {
        uint256 posId = _createLiquidatablePosition();

        vm.prank(liquidator);
        (uint256 marginSeized,) = liquidationEngine.liquidate(posId);

        (uint256 liquidations, uint256 valueLiquidated, uint256 fees) = liquidationEngine.getStats();
        assertEq(liquidations, 1);
        assertEq(valueLiquidated, marginSeized);
        assertGt(fees, 0);
    }

    function test_liquidate_EmitsEvent() public {
        uint256 posId = _createLiquidatablePosition();

        // Use less strict matching - only check indexed params
        vm.expectEmit(true, true, true, false);
        emit LiquidationEngine.PositionLiquidated(posId, liquidator, trader, 1, 1, 1);

        vm.prank(liquidator);
        liquidationEngine.liquidate(posId);
    }

    function test_liquidate_RevertIfNotLiquidatable() public {
        // Create healthy position
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Try to liquidate (should fail)
        uint256 hf = marginEngine.getHealthFactor(posId);
        vm.expectRevert(
            abi.encodeWithSelector(LiquidationEngine.PositionNotLiquidatable.selector, posId, hf)
        );
        vm.prank(liquidator);
        liquidationEngine.liquidate(posId);
    }

    function test_liquidate_RevertIfPaused() public {
        uint256 posId = _createLiquidatablePosition();

        liquidationEngine.setPaused(true);

        vm.expectRevert(LiquidationEngine.ContractPaused.selector);
        vm.prank(liquidator);
        liquidationEngine.liquidate(posId);
    }

    function test_liquidate_RevertIfNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(LiquidationEngine.PositionNotActive.selector, 999)
        );
        vm.prank(liquidator);
        liquidationEngine.liquidate(999);
    }

    /*//////////////////////////////////////////////////////////////
                      PARTIAL LIQUIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_partialLiquidate_Success() public {
        uint256 posId = _createLiquidatablePosition();

        PositionManager.Position memory posBefore = pm.getPosition(posId);

        // Partial liquidate 25% of margin
        uint256 amount = uint256(posBefore.margin) * 25 / 100;

        vm.prank(liquidator);
        uint256 reward = liquidationEngine.partialLiquidate(posId, amount);

        assertGt(reward, 0);

        // Position should still exist with reduced margin
        PositionManager.Position memory posAfter = pm.getPosition(posId);
        assertEq(posAfter.margin, posBefore.margin - uint128(amount));
    }

    function test_partialLiquidate_CapsAtMaxRatio() public {
        uint256 posId = _createLiquidatablePosition();

        PositionManager.Position memory posBefore = pm.getPosition(posId);

        // Try to liquidate 100% (should be capped at 50%)
        uint256 amount = posBefore.margin;

        vm.prank(liquidator);
        liquidationEngine.partialLiquidate(posId, amount);

        PositionManager.Position memory posAfter = pm.getPosition(posId);
        // Should only have liquidated 50%
        uint256 expectedRemaining = uint256(posBefore.margin) * 50 / 100;
        assertEq(posAfter.margin, expectedRemaining);
    }

    function test_partialLiquidate_EmitsEvent() public {
        uint256 posId = _createLiquidatablePosition();

        uint256 amount = MARGIN * 25 / 100;

        // Use less strict matching - only check indexed params
        vm.expectEmit(true, true, false, false);
        emit LiquidationEngine.PartialLiquidation(posId, liquidator, 1, 1);

        vm.prank(liquidator);
        liquidationEngine.partialLiquidate(posId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                      BATCH LIQUIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_batchLiquidate_MultiplePositions() public {
        // Create multiple liquidatable positions
        uint256 posId1 = _createLiquidatablePosition();
        uint256 posId2 = _createLiquidatablePosition();

        uint256[] memory posIds = new uint256[](2);
        posIds[0] = posId1;
        posIds[1] = posId2;

        vm.prank(liquidator);
        (uint256 liquidatedCount, uint256 totalReward) = liquidationEngine.batchLiquidate(posIds);

        assertEq(liquidatedCount, 2);
        assertGt(totalReward, 0);
    }

    function test_batchLiquidate_SkipsHealthyPositions() public {
        uint256 liquidatablePos = _createLiquidatablePosition();

        // Create healthy position
        vm.prank(trader);
        uint256 healthyPos = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN * 3) // Extra margin
        );

        uint256[] memory posIds = new uint256[](2);
        posIds[0] = liquidatablePos;
        posIds[1] = healthyPos;

        vm.prank(liquidator);
        (uint256 liquidatedCount,) = liquidationEngine.batchLiquidate(posIds);

        assertEq(liquidatedCount, 1);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_canLiquidate_ReturnsTrueForLiquidatable() public {
        uint256 posId = _createLiquidatablePosition();

        (bool canLiq, uint256 hf) = liquidationEngine.canLiquidate(posId);

        assertTrue(canLiq);
        assertLt(hf, 1e18); // Health factor < 1
    }

    function test_canLiquidate_ReturnsFalseForHealthy() public {
        vm.prank(trader);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        (bool canLiq, uint256 hf) = liquidationEngine.canLiquidate(posId);

        assertFalse(canLiq);
        assertGt(hf, 1e18);
    }

    function test_canLiquidate_ReturnsFalseForInactive() public {
        (bool canLiq, uint256 hf) = liquidationEngine.canLiquidate(999);
        assertFalse(canLiq);
        assertEq(hf, 0);
    }

    function test_previewLiquidation_ReturnsCorrectAmounts() public {
        uint256 posId = _createLiquidatablePosition();

        (uint256 marginSeized, uint256 reward, uint256 fee) = liquidationEngine.previewLiquidation(posId);

        assertGt(marginSeized, 0);
        assertGt(reward, 0);
        assertGt(fee, 0);

        // FIX C-02: Reward = marginSeized - protocolFee + effectiveBonus
        // Where effectiveBonus = min(bonus, protocolFee)
        // Default: bonus=5%, fee=2%, so effectiveBonus=2%
        // reward = marginSeized - 2% + 2% = marginSeized
        uint256 protocolFeeAmount = marginSeized * 0.02e18 / 1e18;
        uint256 effectiveBonus = 0.02e18; // min(0.05e18, 0.02e18)
        uint256 bonusAmount = marginSeized * effectiveBonus / 1e18;
        uint256 expectedReward = marginSeized - protocolFeeAmount + bonusAmount;
        assertApproxEqRel(reward, expectedReward, 0.01e18);
    }

    function test_previewLiquidation_ZeroForInactive() public {
        (uint256 marginSeized, uint256 reward, uint256 fee) = liquidationEngine.previewLiquidation(999);

        assertEq(marginSeized, 0);
        assertEq(reward, 0);
        assertEq(fee, 0);
    }

    function test_findLiquidatablePositions_FindsCorrectPositions() public {
        // Create mix of liquidatable and healthy positions
        uint256 liquidatable1 = _createLiquidatablePosition();
        uint256 liquidatable2 = _createLiquidatablePosition();

        // Create healthy position
        vm.prank(trader);
        pm.openPosition(true, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN * 3));

        uint256[] memory found = liquidationEngine.findLiquidatablePositions(0, 10);

        assertEq(found.length, 2);
        assertTrue(found[0] == liquidatable1 || found[1] == liquidatable1);
        assertTrue(found[0] == liquidatable2 || found[1] == liquidatable2);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setLiquidationParameters_Success() public {
        liquidationEngine.setLiquidationParameters(0.10e18, 0.05e18, 0.75e18);

        assertEq(liquidationEngine.liquidationBonus(), 0.10e18);
        assertEq(liquidationEngine.protocolFee(), 0.05e18);
        assertEq(liquidationEngine.maxLiquidationRatio(), 0.75e18);
    }

    function test_setLiquidationParameters_RevertIfBonusTooHigh() public {
        vm.expectRevert(LiquidationEngine.InvalidParameters.selector);
        liquidationEngine.setLiquidationParameters(0.25e18, 0.02e18, 0.50e18);
    }

    function test_setLiquidationParameters_RevertIfFeeTooHigh() public {
        vm.expectRevert(LiquidationEngine.InvalidParameters.selector);
        liquidationEngine.setLiquidationParameters(0.05e18, 0.15e18, 0.50e18);
    }

    function test_setLiquidationParameters_RevertIfRatioInvalid() public {
        vm.expectRevert(LiquidationEngine.InvalidParameters.selector);
        liquidationEngine.setLiquidationParameters(0.05e18, 0.02e18, 0);

        vm.expectRevert(LiquidationEngine.InvalidParameters.selector);
        liquidationEngine.setLiquidationParameters(0.05e18, 0.02e18, 1.1e18);
    }

    function test_setLiquidationParameters_OnlyOwner() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        liquidationEngine.setLiquidationParameters(0.10e18, 0.05e18, 0.75e18);
    }

    function test_setLiquidationParameters_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit LiquidationEngine.LiquidationParametersUpdated(0.10e18, 0.05e18, 0.75e18);

        liquidationEngine.setLiquidationParameters(0.10e18, 0.05e18, 0.75e18);
    }

    function test_setProtocolFeeRecipient_Success() public {
        address newRecipient = address(0x4);
        liquidationEngine.setProtocolFeeRecipient(newRecipient);
        assertEq(liquidationEngine.protocolFeeRecipient(), newRecipient);
    }

    function test_setProtocolFeeRecipient_RevertIfZeroAddress() public {
        vm.expectRevert(LiquidationEngine.ZeroAddress.selector);
        liquidationEngine.setProtocolFeeRecipient(address(0));
    }

    function test_setProtocolFeeRecipient_EmitsEvent() public {
        address newRecipient = address(0x4);

        vm.expectEmit(true, true, true, true);
        emit LiquidationEngine.ProtocolFeeRecipientUpdated(newRecipient);

        liquidationEngine.setProtocolFeeRecipient(newRecipient);
    }

    function test_setPaused_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit LiquidationEngine.Paused(true);

        liquidationEngine.setPaused(true);
    }

    function test_withdrawFees_Success() public {
        // Create and liquidate position to accumulate fees
        uint256 posId = _createLiquidatablePosition();

        vm.prank(liquidator);
        liquidationEngine.liquidate(posId);

        uint256 contractBalance = usdc.balanceOf(address(liquidationEngine));
        assertGt(contractBalance, 0);

        uint256 recipientBefore = usdc.balanceOf(feeRecipient);

        liquidationEngine.withdrawFees();

        uint256 recipientAfter = usdc.balanceOf(feeRecipient);
        assertEq(recipientAfter - recipientBefore, contractBalance);
    }

    function test_withdrawFees_RevertIfNoFees() public {
        // Deploy fresh liquidation engine without funds
        LiquidationEngine freshEngine = new LiquidationEngine(
            address(pm),
            address(marginEngine),
            address(usdc),
            feeRecipient
        );

        vm.expectRevert(LiquidationEngine.NoFeesToWithdraw.selector);
        freshEngine.withdrawFees();
    }

    function test_withdrawFees_EmitsEvent() public {
        // Create and liquidate to get fees
        uint256 posId = _createLiquidatablePosition();
        vm.prank(liquidator);
        liquidationEngine.liquidate(posId);

        uint256 balance = usdc.balanceOf(address(liquidationEngine));

        vm.expectEmit(true, true, true, true);
        emit LiquidationEngine.FeesWithdrawn(feeRecipient, balance);

        liquidationEngine.withdrawFees();
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_liquidationReward_CorrectCalculation(
        uint256 bonusSeed,
        uint256 feeSeed
    ) public {
        // Phase 1 Security: Use bounds that respect parameter limits
        // MAX_LIQUIDATION_BONUS = 0.10e18 (10%)
        // MAX_PROTOCOL_FEE = 0.05e18 (5%)
        uint256 bonus = bound(bonusSeed, 0.01e18, 0.10e18);
        uint256 fee = bound(feeSeed, 0.01e18, 0.05e18);

        // Set parameters
        liquidationEngine.setLiquidationParameters(bonus, fee, 0.50e18);

        uint256 posId = _createLiquidatablePosition();

        (uint256 marginSeized, uint256 reward,) = liquidationEngine.previewLiquidation(posId);

        // FIX C-02: Verify reward calculation with corrected math
        // reward = marginSeized - protocolFee + effectiveBonus
        // where effectiveBonus = min(bonus, fee)
        uint256 protocolFeeAmount = marginSeized * fee / 1e18;
        uint256 effectiveBonus = bonus > fee ? fee : bonus;
        uint256 bonusAmount = marginSeized * effectiveBonus / 1e18;
        uint256 expectedReward = marginSeized - protocolFeeAmount + bonusAmount;
        // Cap at marginSeized
        if (expectedReward > marginSeized) {
            expectedReward = marginSeized;
        }
        assertApproxEqRel(reward, expectedReward, 0.01e18);
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a position that becomes liquidatable
    function _createLiquidatablePosition() internal returns (uint256 posId) {
        // Create position with minimum margin, high fixed rate
        vm.prank(trader);
        posId = pm.openPosition(
            true, // Pay high fixed
            uint128(NOTIONAL),
            uint128(0.30e18), // 30% fixed rate
            365, // Long maturity
            uint128(MARGIN)
        );

        // Set floating rate very low
        rateSource.setSupplyRate(0.001e18);
        oracle.updateRate();

        // Advance time to accumulate losses
        vm.warp(block.timestamp + 300 days);
    }
}
