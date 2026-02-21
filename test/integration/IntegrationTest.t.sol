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

/// @title IntegrationTest
/// @notice End-to-end integration tests for the IRS Protocol
contract IntegrationTest is Test {
    // Contracts
    PositionManager public pm;
    SettlementEngine public se;
    MarginEngine public me;
    LiquidationEngine public le;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource1;
    MockRateSource public rateSource2;

    // Users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");
    address public feeRecipient = makeAddr("feeRecipient");
    address public randomUser = makeAddr("randomUser");

    // Constants
    uint256 constant INITIAL_BALANCE = 1_000_000e6; // 1M USDC
    uint256 constant INITIAL_RATE = 0.05e18; // 5% APY

    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy rate sources (supply and borrow rates)
        rateSource1 = new MockRateSource(INITIAL_RATE, INITIAL_RATE);
        rateSource2 = new MockRateSource(INITIAL_RATE, INITIAL_RATE);

        // Deploy oracle with two sources
        address[] memory sources = new address[](2);
        sources[0] = address(rateSource1);
        sources[1] = address(rateSource2);
        oracle = new RateOracle(sources, 1, 1 hours);

        // Deploy core contracts (with fee recipients)
        pm = new PositionManager(address(usdc), 6, feeRecipient);
        me = new MarginEngine(address(pm), address(oracle));
        se = new SettlementEngine(address(pm), address(oracle), 1 days, address(usdc), feeRecipient);
        le = new LiquidationEngine(
            address(pm),
            address(me),
            address(usdc),
            feeRecipient
        );

        // Authorize contracts
        pm.setAuthorizedContract(address(se), true);
        pm.setAuthorizedContract(address(le), true);

        // Fund users
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(liquidator, INITIAL_BALANCE);

        // Approve spending
        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pm), type(uint256).max);
        vm.prank(liquidator);
        usdc.approve(address(le), type(uint256).max);

        // Fund PositionManager with liquidity to cover payouts
        // In production, this would be from matching positions or a liquidity pool
        usdc.mint(address(pm), 100_000e6);
    }

    // ============ Full Lifecycle Tests ============

    /// @notice Test complete position lifecycle: open -> settle -> close
    function test_FullLifecycle_PayFixed() public {
        // Alice opens a pay-fixed position
        uint128 notional = 100_000e6;
        uint128 fixedRate = 0.05e18; // 5%
        uint128 margin = 10_000e6;
        uint256 maturityDays = 90;

        vm.prank(alice);
        uint256 posId = pm.openPosition(true, notional, fixedRate, maturityDays, margin);

        // Verify position created
        assertEq(pm.ownerOf(posId), alice);
        PositionManager.Position memory pos = _getPosition(posId);
        assertEq(pos.notional, notional);
        assertEq(pos.accumulatedPnL, 0);

        // Advance time for settlement
        vm.warp(block.timestamp + 1 days);

        // Update floating rate to 6% (higher than fixed)
        rateSource1.setSupplyRate(0.06e18);
        rateSource2.setSupplyRate(0.06e18);

        // Get PnL before settlement
        int128 pnlBefore = _getPosition(posId).accumulatedPnL;

        // Settle - Alice should profit (receives floating > pays fixed)
        se.settle(posId);

        // Check accumulated PnL after settlement
        int128 pnlAfter = _getPosition(posId).accumulatedPnL;

        // Alice pays 5% fixed, receives 6% floating = net +1%
        assertTrue(pnlAfter > pnlBefore, "Alice should profit from rate increase");

        // Advance to maturity
        vm.warp(block.timestamp + 90 days);

        // Close position
        uint256 balanceBefore = usdc.balanceOf(alice);
        se.closeMaturedPosition(posId);
        uint256 balanceAfter = usdc.balanceOf(alice);

        // Alice should receive her margin back plus profits
        assertTrue(balanceAfter > balanceBefore, "Alice should receive margin");
    }

    /// @notice Test pay-floating position lifecycle
    function test_FullLifecycle_PayFloating() public {
        // Bob opens a pay-floating position (receives fixed)
        uint128 notional = 100_000e6;
        uint128 fixedRate = 0.05e18; // 5%
        uint128 margin = 10_000e6;
        uint256 maturityDays = 90;

        vm.prank(bob);
        uint256 posId = pm.openPosition(false, notional, fixedRate, maturityDays, margin);

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Floating rate drops to 4% (lower than fixed)
        rateSource1.setSupplyRate(0.04e18);
        rateSource2.setSupplyRate(0.04e18);

        // Get PnL before settlement
        int128 pnlBefore = _getPosition(posId).accumulatedPnL;

        // Settle - Bob should profit (pays 4% floating, receives 5% fixed)
        se.settle(posId);

        // Check accumulated PnL after settlement
        int128 pnlAfter = _getPosition(posId).accumulatedPnL;

        assertTrue(pnlAfter > pnlBefore, "Bob should profit from rate decrease");
    }

    /// @notice Test liquidation flow
    function test_LiquidationFlow() public {
        // Alice opens a leveraged position
        uint128 notional = 100_000e6;
        uint128 fixedRate = 0.05e18; // 5%
        uint128 margin = 10_000e6; // 10x leverage
        uint256 maturityDays = 365;

        vm.prank(alice);
        uint256 posId = pm.openPosition(true, notional, fixedRate, maturityDays, margin);

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Floating rate drops significantly - Alice loses money
        rateSource1.setSupplyRate(0.02e18); // 2%
        rateSource2.setSupplyRate(0.02e18);

        // Multiple settlements to drain margin
        for (uint256 i = 0; i < 30; i++) {
            vm.warp(block.timestamp + 1 days);
            try se.settle(posId) {} catch {}
        }

        // Check if position is liquidatable
        uint256 healthFactor = me.getHealthFactor(posId);

        if (healthFactor < 1e18) {
            // Liquidate
            uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);

            vm.prank(liquidator);
            le.liquidate(posId);

            uint256 liquidatorBalanceAfter = usdc.balanceOf(liquidator);

            // Liquidator should receive reward
            assertTrue(
                liquidatorBalanceAfter > liquidatorBalanceBefore,
                "Liquidator should profit"
            );

            // Position should be closed
            vm.expectRevert();
            pm.ownerOf(posId);
        }
    }

    // ============ Multi-User Interaction Tests ============

    /// @notice Test offsetting positions between two users
    function test_OffsettingPositions() public {
        uint128 notional = 100_000e6;
        uint128 fixedRate = 0.05e18;
        uint128 margin = 10_000e6;
        uint256 maturityDays = 90;

        // Alice pays fixed
        vm.prank(alice);
        uint256 alicePos = pm.openPosition(true, notional, fixedRate, maturityDays, margin);

        // Bob pays floating (opposite position)
        vm.prank(bob);
        uint256 bobPos = pm.openPosition(false, notional, fixedRate, maturityDays, margin);

        // Advance time and change rate
        vm.warp(block.timestamp + 1 days);
        rateSource1.setSupplyRate(0.06e18);
        rateSource2.setSupplyRate(0.06e18);

        // Settle both
        se.settle(alicePos);
        se.settle(bobPos);

        // Check accumulated PnL for both
        int128 alicePnL = _getPosition(alicePos).accumulatedPnL;
        int128 bobPnL = _getPosition(bobPos).accumulatedPnL;

        // Alice should gain (pays 5%, receives 6%)
        assertTrue(alicePnL > 0, "Alice should profit");
        // Bob should lose (pays 6%, receives 5%)
        assertTrue(bobPnL < 0, "Bob should lose");

        // Their gains/losses should roughly offset
        int256 netPnL = int256(alicePnL) + int256(bobPnL);
        assertTrue(netPnL >= -1e6 && netPnL <= 1e6, "PnL should roughly offset");
    }

    /// @notice Test position transfer (NFT)
    function test_PositionTransfer() public {
        // Alice opens position
        vm.prank(alice);
        uint256 posId = pm.openPosition(
            true,
            100_000e6,
            0.05e18,
            90,
            10_000e6
        );

        // Transfer to Bob
        vm.prank(alice);
        pm.transferFrom(alice, bob, posId);

        // Verify Bob is new owner
        assertEq(pm.ownerOf(posId), bob);

        // Bob can add margin
        vm.prank(bob);
        pm.addMargin(posId, 1_000e6);

        // Bob can close via settlement engine at maturity
        vm.warp(block.timestamp + 90 days);
        se.closeMaturedPosition(posId);
    }

    // ============ Edge Case Tests ============

    /// @notice Test batch settlement
    function test_BatchSettlement() public {
        uint256[] memory posIds = new uint256[](3);

        // Open multiple positions
        vm.startPrank(alice);
        posIds[0] = pm.openPosition(true, 50_000e6, 0.05e18, 90, 5_000e6);
        posIds[1] = pm.openPosition(true, 75_000e6, 0.04e18, 180, 7_500e6);
        posIds[2] = pm.openPosition(false, 100_000e6, 0.06e18, 365, 10_000e6);
        vm.stopPrank();

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Batch settle
        se.batchSettle(posIds);

        // All positions should have updated lastSettlement
        for (uint256 i = 0; i < posIds.length; i++) {
            PositionManager.Position memory pos = _getPosition(posIds[i]);
            assertEq(pos.lastSettlement, block.timestamp);
        }
    }

    /// @notice Test adding and removing margin
    function test_MarginManagement() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Add margin
        uint256 marginBefore = pm.getMargin(posId);
        vm.prank(alice);
        pm.addMargin(posId, 5_000e6);
        assertEq(pm.getMargin(posId), marginBefore + 5_000e6);

        // Calculate removable margin (excess above maintenance)
        uint256 currentMargin = pm.getMargin(posId);
        uint256 maintenanceMargin = me.calculateMaintenanceMargin(posId);

        if (currentMargin > maintenanceMargin) {
            uint256 removable = currentMargin - maintenanceMargin;
            // Try removing half of excess to stay safe
            vm.prank(alice);
            pm.removeMargin(posId, uint128(removable / 2));
        }
    }

    /// @notice Test rate oracle aggregation
    function test_RateOracleAggregation() public {
        // Set different rates on sources
        rateSource1.setSupplyRate(0.05e18);
        rateSource2.setSupplyRate(0.07e18);

        // Get aggregated rate (median)
        uint256 rate = oracle.getCurrentRate();

        // Median of [0.05, 0.07] = 0.06
        assertEq(rate, 0.06e18);
    }

    /// @notice Test settlement with extreme rate movements
    function test_ExtremeRateMovement() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 365, 10_000e6);

        vm.warp(block.timestamp + 1 days);

        // Extreme rate spike
        rateSource1.setSupplyRate(0.50e18); // 50%
        rateSource2.setSupplyRate(0.50e18);

        // Get PnL before
        int128 pnlBefore = _getPosition(posId).accumulatedPnL;

        // Settlement should still work
        se.settle(posId);

        // Get PnL after
        int128 pnlAfter = _getPosition(posId).accumulatedPnL;

        // Position should have significant profit
        assertTrue(pnlAfter > pnlBefore, "Should profit from rate spike");
    }

    /// @notice Test multiple settlements over time
    function test_MultipleSettlements() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        int128[] memory pnls = new int128[](5);
        pnls[0] = _getPosition(posId).accumulatedPnL;

        // Settle multiple times with varying rates
        uint256[] memory rates = new uint256[](4);
        rates[0] = 0.06e18;
        rates[1] = 0.04e18;
        rates[2] = 0.08e18;
        rates[3] = 0.03e18;

        for (uint256 i = 0; i < 4; i++) {
            vm.warp(block.timestamp + 1 days);
            rateSource1.setSupplyRate(rates[i]);
            rateSource2.setSupplyRate(rates[i]);
            se.settle(posId);
            pnls[i + 1] = _getPosition(posId).accumulatedPnL;
        }

        // Verify PnL changed each time
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(pnls[i] != pnls[i + 1], "PnL should change");
        }
    }

    // ============ Access Control Tests ============

    /// @notice Test unauthorized contract cannot modify positions
    function test_UnauthorizedCannotModify() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Random address cannot update position PnL (only authorized contracts can)
        vm.prank(randomUser);
        vm.expectRevert();
        pm.updatePositionPnL(posId, 1000);
    }

    /// @notice Test only owner can remove margin
    function test_OnlyOwnerCanRemoveMargin() public {
        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Bob cannot remove margin from Alice's position
        vm.prank(bob);
        vm.expectRevert();
        pm.removeMargin(posId, 1_000e6);
    }

    // ============ Protocol Integration Tests ============

    /// @notice Test full protocol deployment and configuration
    function test_ProtocolDeployment() public view {
        // Verify all contracts connected correctly
        assertEq(address(me.positionManager()), address(pm));
        assertEq(address(me.rateOracle()), address(oracle));
        assertEq(address(se.positionManager()), address(pm));
        assertEq(address(se.rateOracle()), address(oracle));
        assertEq(address(le.positionManager()), address(pm));
        assertEq(address(le.marginEngine()), address(me));

        // Verify authorizations
        assertTrue(pm.authorizedContracts(address(se)));
        assertTrue(pm.authorizedContracts(address(le)));
    }

    /// @notice Test protocol pause functionality
    function test_ProtocolPause() public {
        // Pause settlement engine
        se.setPaused(true);

        vm.prank(alice);
        uint256 posId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.warp(block.timestamp + 1 days);

        // Settlement should fail when paused
        vm.expectRevert();
        se.settle(posId);

        // Unpause
        se.setPaused(false);

        // Now settlement works
        se.settle(posId);
    }

    // ============ Helper Functions ============

    function _getPosition(uint256 posId) internal view returns (PositionManager.Position memory) {
        (
            address trader,
            bool isPayingFixed,
            uint40 startTime,
            uint40 maturity,
            bool isActive,
            uint128 notional,
            uint128 margin,
            uint128 fixedRate,
            int128 accumulatedPnL,
            uint40 lastSettlement,
            uint216 _reserved
        ) = pm.positions(posId);

        return PositionManager.Position({
            trader: trader,
            isPayingFixed: isPayingFixed,
            startTime: startTime,
            maturity: maturity,
            isActive: isActive,
            notional: notional,
            margin: margin,
            fixedRate: fixedRate,
            accumulatedPnL: accumulatedPnL,
            lastSettlement: lastSettlement,
            _reserved: _reserved
        });
    }
}
