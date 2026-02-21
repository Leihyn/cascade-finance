// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/OrderBook.sol";
import "../../src/core/PositionManager.sol";
import "../../src/mocks/MockERC20.sol";

/**
 * @title C-01 Proof of Concept: OrderBook Calls Wrong Function
 * @notice Demonstrates that OrderBook._createPositionFor() always reverts
 *         because it calls openPosition() instead of openPositionFor()
 *
 * VULNERABILITY:
 * - OrderBook.safeTransfer(positionManager, margin) pushes tokens
 * - OrderBook.openPosition() then tries to safeTransferFrom(OrderBook, PM, margin)
 * - This fails because tokens are already sent AND no approval exists
 *
 * EXPECTED: Order matching creates two positions
 * ACTUAL: Transaction reverts with "ERC20: insufficient allowance"
 */
contract C01_OrderBookWrongFunctionTest is Test {
    PositionManager public pm;
    OrderBook public orderBook;
    MockERC20 public usdc;

    address alice = address(0x1);
    address bob = address(0x2);
    address feeRecipient = address(0xFEE);

    uint256 constant ONE_USDC = 1e6;

    function setUp() public {
        // Deploy contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        pm = new PositionManager(address(usdc), 6, feeRecipient);
        orderBook = new OrderBook(address(pm), address(usdc), feeRecipient);

        // IMPORTANT: Authorize OrderBook on PositionManager
        pm.setAuthorizedContract(address(orderBook), true);

        // Fund users
        usdc.mint(alice, 1_000_000 * ONE_USDC);
        usdc.mint(bob, 1_000_000 * ONE_USDC);

        // Approve OrderBook
        vm.prank(alice);
        usdc.approve(address(orderBook), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(orderBook), type(uint256).max);
    }

    /**
     * @notice PoC: Matching two valid orders reverts
     * @dev This demonstrates the critical bug in _createPositionFor()
     */
    function test_POC_OrderMatchingReverts() public {
        // Step 1: Alice creates a pay-fixed order
        vm.prank(alice);
        uint256 aliceOrderId = orderBook.createOrder(
            true,           // isPayingFixed
            100_000e6,      // notional: $100k
            0.04e18,        // minRate: 4%
            0.06e18,        // maxRate: 6%
            90,             // maturity: 90 days
            10_000e6,       // margin: $10k (10%)
            1 hours         // duration
        );

        // Step 2: Bob creates a pay-floating order (compatible)
        vm.prank(bob);
        uint256 bobOrderId = orderBook.createOrder(
            false,          // pay floating (receive fixed)
            100_000e6,      // same notional
            0.05e18,        // minRate: 5% (within Alice's range)
            0.07e18,        // maxRate: 7%
            90,             // same maturity
            10_000e6,       // margin
            1 hours
        );

        // Verify orders are compatible
        OrderBook.Order memory aliceOrder = orderBook.getOrder(aliceOrderId);
        OrderBook.Order memory bobOrder = orderBook.getOrder(bobOrderId);

        assertTrue(aliceOrder.isActive, "Alice order should be active");
        assertTrue(bobOrder.isActive, "Bob order should be active");
        assertTrue(aliceOrder.isPayingFixed, "Alice should be pay-fixed");
        assertFalse(bobOrder.isPayingFixed, "Bob should be pay-floating");

        // Orders are compatible: Bob's minRate (5%) <= Alice's maxRate (6%)
        assertLe(bobOrder.minRate, aliceOrder.maxRate, "Orders should be rate-compatible");

        // Step 3: Try to match orders - THIS WILL REVERT
        // The bug: _createPositionFor calls openPosition() which tries to pull tokens
        // that OrderBook already pushed via safeTransfer
        vm.expectRevert(); // Will revert due to the bug
        orderBook.matchOrders(aliceOrderId, bobOrderId);
    }

    /**
     * @notice Shows the exact failure point
     * @dev The revert happens because:
     *      1. OrderBook.safeTransfer(PM, margin) succeeds
     *      2. PM.openPosition() calls safeTransferFrom(OrderBook, PM, margin)
     *      3. OrderBook has no tokens left AND never approved PM
     */
    function test_POC_ExactFailureReason() public {
        // Create compatible orders
        vm.prank(alice);
        orderBook.createOrder(true, 100_000e6, 0.04e18, 0.06e18, 90, 10_000e6, 1 hours);

        vm.prank(bob);
        orderBook.createOrder(false, 100_000e6, 0.05e18, 0.07e18, 90, 10_000e6, 1 hours);

        // Check OrderBook's approval to PositionManager - it's ZERO!
        uint256 allowance = usdc.allowance(address(orderBook), address(pm));
        assertEq(allowance, 0, "OrderBook has no approval to PM");

        // This is the first part of the bug - even if OrderBook had tokens,
        // it never approved PM to spend them

        // The second part: OrderBook sends tokens BEFORE calling openPosition,
        // so it has no tokens when openPosition tries to pull

        // Try matching - will fail
        vm.expectRevert();
        orderBook.matchOrders(0, 1);
    }

    /**
     * @notice Demonstrates the correct fix would work
     * @dev If openPositionFor() were called instead, it would succeed
     *      because openPositionFor expects tokens to be pre-transferred
     */
    function test_POC_OpenPositionForWouldWork() public {
        // This test shows that openPositionFor() works correctly
        // when tokens are pre-transferred (the pattern OrderBook uses)

        // Authorize this test contract
        pm.setAuthorizedContract(address(this), true);

        // Pre-transfer margin to PositionManager (like OrderBook does)
        usdc.mint(address(this), 10_000e6);
        usdc.transfer(address(pm), 10_000e6);

        // openPositionFor should succeed (no safeTransferFrom inside)
        uint256 positionId = pm.openPositionFor(
            alice,          // trader
            true,           // isPayingFixed
            100_000e6,      // notional
            0.05e18,        // fixedRate
            90,             // maturity
            10_000e6        // margin (already in PM)
        );

        // Verify position was created correctly
        assertEq(pm.ownerOf(positionId), alice);
        PositionManager.Position memory pos = pm.getPosition(positionId);
        assertEq(pos.trader, alice);
        assertEq(pos.notional, 100_000e6);
    }

    /**
     * @notice Shows funds get stuck when orders can't match
     * @dev Users deposit margin for orders but can never get matched
     */
    function test_POC_FundsGetStuck() public {
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 bobBalanceBefore = usdc.balanceOf(bob);

        // Create orders - margin is transferred to OrderBook
        vm.prank(alice);
        orderBook.createOrder(true, 100_000e6, 0.04e18, 0.06e18, 90, 10_000e6, 1 hours);

        vm.prank(bob);
        orderBook.createOrder(false, 100_000e6, 0.05e18, 0.07e18, 90, 10_000e6, 1 hours);

        // Margin is now in OrderBook
        assertEq(usdc.balanceOf(address(orderBook)), 20_000e6);
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore - 10_000e6);
        assertEq(usdc.balanceOf(bob), bobBalanceBefore - 10_000e6);

        // Matching fails
        vm.expectRevert();
        orderBook.matchOrders(0, 1);

        // Users can only get funds back by cancelling orders
        // They CANNOT get matched positions - the core functionality is broken

        vm.prank(alice);
        orderBook.cancelOrder(0);
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore);

        vm.prank(bob);
        orderBook.cancelOrder(1);
        assertEq(usdc.balanceOf(bob), bobBalanceBefore);
    }
}
