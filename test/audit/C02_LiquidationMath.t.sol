// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/risk/LiquidationEngine.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

/**
 * @title C-02 Verification: LiquidationEngine Math Fixed
 * @notice Verifies that the liquidation math bug has been fixed
 *
 * PREVIOUS VULNERABILITY:
 * - Default: liquidationBonus = 5%, protocolFee = 2%
 * - rewardMultiplier = 1 + 0.05 - 0.02 = 1.03 (103%)
 * - If marginSeized = 50, liquidatorReward = 51.5
 * - Contract receives 50, tries to send 51.5 -> REVERT
 *
 * FIX APPLIED:
 * - Bonus is now capped to not exceed protocol fee amount
 * - Liquidator reward never exceeds seized amount
 * - Liquidations now succeed, protecting protocol from bad debt
 */
contract C02_LiquidationMathTest is Test {
    PositionManager public pm;
    LiquidationEngine public liquidationEngine;
    MarginEngine public marginEngine;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address alice = address(0x1);
    address liquidator = address(0x2);
    address feeRecipient = address(0xFEE);

    uint256 constant ONE_USDC = 1e6;

    function setUp() public {
        // Deploy contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Setup rate oracle with mock source
        rateSource = new MockRateSource(0.05e18, 0.06e18); // 5% supply, 6% borrow

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);

        // Deploy core contracts
        pm = new PositionManager(address(usdc), 6, feeRecipient);
        marginEngine = new MarginEngine(address(pm), address(oracle));
        liquidationEngine = new LiquidationEngine(
            address(pm),
            address(marginEngine),
            address(usdc),
            feeRecipient
        );

        // Authorize contracts
        pm.setAuthorizedContract(address(liquidationEngine), true);

        // Fund users
        usdc.mint(alice, 1_000_000 * ONE_USDC);

        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);
    }

    /**
     * @notice Verify: Liquidation now succeeds with fixed math
     * @dev Shows the fix works - liquidations complete successfully
     */
    function test_POC_LiquidationMathReverts() public {
        // Step 1: Create a position that will become liquidatable
        vm.prank(alice);
        uint256 positionId = pm.openPosition(
            true,           // pay fixed
            100_000e6,      // $100k notional
            0.05e18,        // 5% fixed rate
            90,             // 90 days
            10_000e6        // $10k margin (10%)
        );

        // Step 2: Simulate rate movement to make position underwater
        // Increase floating rate significantly to create loss for pay-fixed position
        rateSource.setSupplyRate(0.01e18); // Drop to 1% (pay-fixed loses money)

        // Warp time to accumulate negative PnL
        vm.warp(block.timestamp + 30 days);
        oracle.updateRate();

        // Step 3: Make position liquidatable by applying large negative PnL
        // Authorize this test to apply PnL
        pm.setAuthorizedContract(address(this), true);

        // Apply large negative PnL to make position underwater
        pm.updatePositionPnL(positionId, -8_000e6); // -$8k loss

        // Verify position is liquidatable
        assertTrue(marginEngine.isLiquidatable(positionId), "Position should be liquidatable");

        // Step 4: Liquidation now SUCCEEDS with the fix applied
        uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);

        vm.prank(liquidator);
        (uint256 marginSeized, uint256 liquidatorReward) = liquidationEngine.liquidate(positionId);

        uint256 liquidatorBalanceAfter = usdc.balanceOf(liquidator);

        // Verify liquidation succeeded
        assertTrue(marginSeized > 0, "Margin should be seized");
        assertTrue(liquidatorReward > 0, "Liquidator should receive reward");
        assertTrue(liquidatorBalanceAfter > liquidatorBalanceBefore, "Liquidator balance should increase");

        // Verify reward never exceeds seized amount (the fix)
        assertLe(liquidatorReward, marginSeized, "Reward should not exceed seized amount");

        console.log("Liquidation SUCCEEDED - FIX VERIFIED");
        console.log("marginSeized:", marginSeized);
        console.log("liquidatorReward:", liquidatorReward);
    }

    /**
     * @notice Shows exact numeric breakdown of the bug
     */
    function test_POC_NumericBreakdown() public {
        // Get the default parameters
        uint256 liquidationBonus = liquidationEngine.liquidationBonus();
        uint256 protocolFee = liquidationEngine.protocolFee();
        uint256 maxLiquidationRatio = liquidationEngine.maxLiquidationRatio();

        console.log("=== Default Parameters ===");
        console.log("liquidationBonus:", liquidationBonus);      // 0.05e18 = 5%
        console.log("protocolFee:", protocolFee);                // 0.02e18 = 2%
        console.log("maxLiquidationRatio:", maxLiquidationRatio); // 0.50e18 = 50%

        // Calculate the problematic multiplier
        uint256 rewardMultiplier = 1e18 + liquidationBonus - protocolFee;
        console.log("\n=== Calculation ===");
        console.log("rewardMultiplier:", rewardMultiplier); // 1.03e18 = 103%

        // For a position with $100 margin:
        uint256 margin = 100e18;
        uint256 marginSeized = (margin * maxLiquidationRatio) / 1e18;
        uint256 liquidatorReward = (marginSeized * rewardMultiplier) / 1e18;

        console.log("\n=== For $100 margin position ===");
        console.log("marginSeized:", marginSeized);       // 50
        console.log("liquidatorReward:", liquidatorReward); // 51.5

        // THE BUG: reward > seized
        assertGt(liquidatorReward, marginSeized, "Reward exceeds seized - BUG CONFIRMED");

        console.log("\n=== The Problem ===");
        console.log("Contract receives:", marginSeized);
        console.log("Contract must pay:", liquidatorReward);
        console.log("SHORTFALL:", liquidatorReward - marginSeized);
    }

    /**
     * @notice Shows that the cap is checking wrong value
     */
    function test_POC_WrongCap() public {
        // The cap checks against pos.margin, not marginSeized
        // This means for margin=100, marginSeized=50, reward=51.5:
        // - Cap check: 51.5 > 100? NO
        // - So cap doesn't apply, but 51.5 > 50 (actual received)

        uint256 liquidationBonus = 0.05e18;
        uint256 protocolFee = 0.02e18;
        uint256 maxLiquidationRatio = 0.50e18;

        uint256 margin = 100e18;
        uint256 marginSeized = (margin * maxLiquidationRatio) / 1e18; // 50

        uint256 rewardMultiplier = 1e18 + liquidationBonus - protocolFee;
        uint256 liquidatorReward = (marginSeized * rewardMultiplier) / 1e18; // 51.5

        // The code does: if (liquidatorReward > pos.margin)
        // But should do: if (liquidatorReward > marginSeized)

        bool currentCapTriggered = liquidatorReward > margin;
        bool correctCapWouldTrigger = liquidatorReward > marginSeized;

        console.log("Current cap triggers:", currentCapTriggered);   // false
        console.log("Correct cap would trigger:", correctCapWouldTrigger); // true

        assertFalse(currentCapTriggered, "Current cap doesn't trigger");
        assertTrue(correctCapWouldTrigger, "Correct cap should trigger");
    }

    /**
     * @notice Shows liquidation would work with fixed math
     */
    function test_POC_FixedMathWorks() public {
        // If we cap reward to marginSeized, liquidations work

        uint256 liquidationBonus = 0.05e18;
        uint256 protocolFee = 0.02e18;
        uint256 maxLiquidationRatio = 0.50e18;

        uint256 margin = 100e18;
        uint256 marginSeized = (margin * maxLiquidationRatio) / 1e18; // 50

        // FIXED MATH: bonus comes from protocol fee, doesn't exceed seized
        uint256 protocolFeeAmount = (marginSeized * protocolFee) / 1e18; // 1
        uint256 effectiveBonus = liquidationBonus > protocolFee ? protocolFee : liquidationBonus;
        uint256 bonusAmount = (marginSeized * effectiveBonus) / 1e18; // 1

        uint256 fixedReward = marginSeized - protocolFeeAmount + bonusAmount; // 50

        console.log("=== Fixed Math ===");
        console.log("marginSeized:", marginSeized);       // 50
        console.log("protocolFeeAmount:", protocolFeeAmount); // 1
        console.log("effectiveBonus:", effectiveBonus);    // 0.02e18 (capped)
        console.log("bonusAmount:", bonusAmount);          // 1
        console.log("fixedReward:", fixedReward);          // 50

        assertLe(fixedReward, marginSeized, "Fixed reward never exceeds seized");
    }

    /**
     * @notice Verify: Partial liquidation now works
     */
    function test_POC_PartialLiquidationSameBug() public {
        // Create and make position liquidatable
        vm.prank(alice);
        uint256 positionId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        pm.setAuthorizedContract(address(this), true);
        pm.updatePositionPnL(positionId, -8_000e6);

        assertTrue(marginEngine.isLiquidatable(positionId));

        // Partial liquidation now SUCCEEDS with the fix
        uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);

        vm.prank(liquidator);
        uint256 reward = liquidationEngine.partialLiquidate(positionId, 5_000e6);

        uint256 liquidatorBalanceAfter = usdc.balanceOf(liquidator);

        assertTrue(reward > 0, "Liquidator should receive reward");
        assertTrue(liquidatorBalanceAfter > liquidatorBalanceBefore, "Balance should increase");

        console.log("Partial liquidation SUCCEEDED - FIX VERIFIED");
        console.log("Reward:", reward);
    }

    /**
     * @notice Verify: Batch liquidation now succeeds
     */
    function test_POC_BatchLiquidationAllFail() public {
        // Create multiple liquidatable positions
        vm.startPrank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        vm.stopPrank();

        pm.setAuthorizedContract(address(this), true);
        pm.updatePositionPnL(0, -8_000e6);
        pm.updatePositionPnL(1, -8_000e6);
        pm.updatePositionPnL(2, -8_000e6);

        uint256[] memory positionIds = new uint256[](3);
        positionIds[0] = 0;
        positionIds[1] = 1;
        positionIds[2] = 2;

        // Batch liquidation - all SUCCEED with the fix
        vm.prank(liquidator);
        (uint256 liquidated, uint256 totalReward) = liquidationEngine.batchLiquidate(positionIds);

        assertEq(liquidated, 3, "All positions should be liquidated");
        assertGt(totalReward, 0, "Total reward should be positive");

        // Protocol is protected from bad debt
        console.log("Liquidated:", liquidated);
        console.log("Total Reward:", totalReward);
        console.log("PROTOCOL PROTECTED - FIX VERIFIED");
    }
}
