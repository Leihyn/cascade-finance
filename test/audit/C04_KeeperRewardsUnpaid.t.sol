// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

/**
 * @title C-04 Verification: Keeper Rewards Now Paid
 * @notice Verifies that the keeper reward payment bug has been fixed
 *
 * PREVIOUS VULNERABILITY:
 * - settle() and settleInternal() tracked totalKeeperRewardsPaid
 * - KeeperRewardPaid events were emitted
 * - BUT no safeTransfer() to keeper ever happened
 * - withdrawFees() sent ALL fees to protocol, ignoring keeper accounting
 *
 * FIX APPLIED:
 * - SettlementEngine now calls positionManager.payKeeper()
 * - Keepers receive their reward immediately on settlement
 * - Payment comes from PositionManager (where tokens are held)
 */
contract C04_KeeperRewardsUnpaidTest is Test {
    PositionManager public pm;
    SettlementEngine public settlement;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address alice = address(0x1);
    address keeper = address(0x2);
    address feeRecipient = address(0xFEE);

    uint256 constant ONE_USDC = 1e6;

    event KeeperRewardPaid(address indexed keeper, uint256 indexed positionId, uint256 reward);

    function setUp() public {
        // Deploy contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);

        rateSource = new MockRateSource(0.05e18, 0.06e18);

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();

        pm = new PositionManager(address(usdc), 6, feeRecipient);
        settlement = new SettlementEngine(
            address(pm),
            address(oracle),
            1 days,          // settlement interval
            address(usdc),
            feeRecipient
        );

        // Authorize settlement engine
        pm.setAuthorizedContract(address(settlement), true);

        // Fund and create position
        usdc.mint(alice, 1_000_000 * ONE_USDC);
        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);

        vm.prank(alice);
        pm.openPosition(true, 1_000_000e6, 0.05e18, 90, 100_000e6);

        // Fund PositionManager with extra liquidity for keeper payments
        usdc.mint(address(pm), 100_000e6);
    }

    /**
     * @notice Verify: Keeper now receives payment
     */
    function test_POC_KeeperGetsNothing() public {
        // Check initial keeper balance
        uint256 keeperBalanceBefore = usdc.balanceOf(keeper);
        assertEq(keeperBalanceBefore, 0, "Keeper starts with 0");

        // Warp time to allow settlement
        vm.warp(block.timestamp + 2 days);

        // Make position have positive PnL (so fees are collected)
        rateSource.setSupplyRate(0.10e18); // Rate increased - pay-fixed profits
        oracle.updateRate();

        // Get keeper reward percentage
        uint256 keeperRewardPercentage = settlement.keeperRewardPercentage();
        console.log("Keeper reward percentage:", keeperRewardPercentage);
        assertTrue(keeperRewardPercentage > 0, "Keeper reward should be > 0");

        // Keeper settles position
        vm.prank(keeper);
        settlement.settle(0);

        // Check: Event was emitted (tracking happened)
        uint256 totalKeeperRewardsPaid = settlement.totalKeeperRewardsPaid();
        console.log("totalKeeperRewardsPaid (tracked):", totalKeeperRewardsPaid);
        assertTrue(totalKeeperRewardsPaid > 0, "Reward was tracked");

        // Check: Keeper NOW receives payment - FIX VERIFIED
        uint256 keeperBalanceAfter = usdc.balanceOf(keeper);
        console.log("Keeper balance after:", keeperBalanceAfter);

        assertEq(keeperBalanceAfter, totalKeeperRewardsPaid, "Keeper received payment - FIX VERIFIED");

        console.log("\n=== FIX VERIFIED ===");
        console.log("Reward tracked:", totalKeeperRewardsPaid);
        console.log("Reward paid:", keeperBalanceAfter);
        console.log("Keeper received proper payment");
    }

    /**
     * @notice Shows event emission suggests payment happened
     */
    function test_POC_MisleadingEvents() public {
        vm.warp(block.timestamp + 2 days);
        rateSource.setSupplyRate(0.10e18);
        oracle.updateRate();

        // Expect KeeperRewardPaid event to be emitted
        // This is misleading because no payment actually occurs
        vm.expectEmit(true, true, false, false);
        emit KeeperRewardPaid(keeper, 0, 0); // Amount doesn't matter, event is emitted

        vm.prank(keeper);
        settlement.settle(0);

        console.log("Event emitted but no payment made - MISLEADING");
    }

    /**
     * @notice Shows keeper rewards are now paid immediately - FIX VERIFIED
     * @dev Note: Protocol fee withdrawal is a separate issue (fees are in PositionManager)
     */
    function test_POC_WithdrawFeesIgnoresKeepers() public {
        // First, have keeper do some settlements
        vm.warp(block.timestamp + 2 days);
        rateSource.setSupplyRate(0.10e18);
        oracle.updateRate();

        // Record keeper balance before settlement
        uint256 keeperBalanceBefore = usdc.balanceOf(keeper);

        vm.prank(keeper);
        settlement.settle(0);

        // Keeper should have received payment immediately
        uint256 keeperBalanceAfter = usdc.balanceOf(keeper);
        uint256 keeperReceived = keeperBalanceAfter - keeperBalanceBefore;

        // Get tracked values
        (uint256 settlementFees, uint256 closeFees, uint256 totalFees) = settlement.getTotalFeesCollected();
        uint256 keeperRewardsTracked = settlement.totalKeeperRewardsPaid();

        console.log("Settlement fees collected:", settlementFees);
        console.log("Close fees collected:", closeFees);
        console.log("Total fees:", totalFees);
        console.log("Keeper rewards tracked:", keeperRewardsTracked);
        console.log("Keeper received:", keeperReceived);

        // FIX VERIFIED: Keeper received payment immediately via PositionManager.payKeeper()
        assertEq(keeperReceived, keeperRewardsTracked, "Keeper received payment during settlement");
        assertTrue(keeperReceived > 0, "Keeper received non-zero reward");

        console.log("\nKEEPER REWARDS WORKING - FIX VERIFIED");
        console.log("Note: Protocol fee withdrawal handled separately by PositionManager.withdrawTradingFees()");
    }

    /**
     * @notice Shows no claimKeeperReward function exists
     */
    function test_POC_NoClaimFunction() public {
        // Search for any function keepers can call to claim rewards
        // Spoiler: It doesn't exist

        // The only functions keepers can call:
        // - settle() - does settlement, tracks reward, NO PAYMENT
        // - batchSettle() - same

        // There is NO:
        // - claimKeeperReward()
        // - withdrawKeeperReward()
        // - Any other claim mechanism

        console.log("Available keeper functions:");
        console.log("- settle(positionId) - tracks reward, no payment");
        console.log("- batchSettle(positionIds) - tracks reward, no payment");
        console.log("");
        console.log("Missing functions:");
        console.log("- claimKeeperReward() - DOES NOT EXIST");
        console.log("- withdrawKeeperReward() - DOES NOT EXIST");

        // Keeper's only option: hope protocol manually sends them money
        // (spoiler: they won't)
    }

    /**
     * @notice Verify: Batch settlement now pays keeper
     */
    function test_POC_BatchSettlementSameIssue() public {
        // Create more positions
        usdc.mint(alice, 1_000_000e6);
        vm.startPrank(alice);
        usdc.approve(address(pm), type(uint256).max);
        pm.openPosition(true, 500_000e6, 0.05e18, 90, 50_000e6);
        pm.openPosition(true, 500_000e6, 0.05e18, 90, 50_000e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);
        rateSource.setSupplyRate(0.10e18);
        oracle.updateRate();

        uint256 keeperBalanceBefore = usdc.balanceOf(keeper);

        uint256[] memory positionIds = new uint256[](3);
        positionIds[0] = 0;
        positionIds[1] = 1;
        positionIds[2] = 2;

        vm.prank(keeper);
        settlement.batchSettle(positionIds);

        uint256 keeperBalanceAfter = usdc.balanceOf(keeper);
        uint256 totalTracked = settlement.totalKeeperRewardsPaid();

        console.log("Positions settled: 3");
        console.log("Total rewards tracked:", totalTracked);
        console.log("Total rewards paid:", keeperBalanceAfter - keeperBalanceBefore);

        // Keeper NOW receives payment - FIX VERIFIED
        assertEq(keeperBalanceAfter - keeperBalanceBefore, totalTracked, "Keeper received all tracked rewards");
        assertTrue(keeperBalanceAfter > keeperBalanceBefore, "Keeper balance should increase");

        console.log("BATCH SETTLEMENT FIX VERIFIED");
    }

    /**
     * @notice Shows the economic impact
     */
    function test_POC_EconomicImpact() public {
        console.log("=== Economic Impact Analysis ===");

        uint256 keeperRewardPct = settlement.keeperRewardPercentage();
        uint256 settlementFeePct = settlement.settlementFee();

        console.log("Settlement fee: ", settlementFeePct * 100 / 1e18, "%");
        console.log("Keeper reward (of fee): ", keeperRewardPct * 100 / 1e18, "%");

        // For $1M notional with 5% rate over 30 days:
        // Settlement = 1M * 0.05 * 30/365 = ~$4,109
        // Fee = $4,109 * 1% = ~$41
        // Keeper should get = $41 * 10% = ~$4.10

        // But keeper gets: $0
        // Protocol gets: $41

        console.log("\nFor $1M notional settled monthly:");
        console.log("Expected keeper revenue: ~$4.10/settlement");
        console.log("Actual keeper revenue: $0");
        console.log("");
        console.log("With 1000 settlements/month:");
        console.log("Expected: ~$4,100");
        console.log("Actual: $0");
        console.log("");
        console.log("Rational keepers will not participate.");
        console.log("Positions may never settle.");
        console.log("Protocol becomes non-functional.");
    }
}
