// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/mocks/MockERC20.sol";

contract PositionManagerTest is Test {
    PositionManager public pm;
    MockERC20 public usdc;

    address alice = address(0x1);
    address bob = address(0x2);
    address settlement = address(0x3);

    uint256 constant USDC_DECIMALS = 6;
    uint256 constant ONE_USDC = 1e6;

    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy position manager (with fee recipient)
        pm = new PositionManager(address(usdc), 6, address(this));

        // Authorize settlement contract
        pm.setAuthorizedContract(settlement, true);

        // Fund test users
        usdc.mint(alice, 1_000_000 * ONE_USDC);
        usdc.mint(bob, 1_000_000 * ONE_USDC);

        // Approve position manager
        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pm), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          OPEN POSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_openPosition_PayFixed_Success() public {
        vm.prank(alice);
        uint256 positionId = pm.openPosition(
            true,           // isPayingFixed
            100_000e6,      // notional: $100k
            0.05e18,        // fixedRate: 5%
            90,             // maturity: 90 days
            10_000e6        // margin: $10k (10%)
        );

        assertEq(positionId, 0);
        assertEq(pm.ownerOf(0), alice);

        PositionManager.Position memory pos = pm.getPosition(0);
        assertEq(pos.trader, alice);
        assertTrue(pos.isPayingFixed);
        assertEq(pos.notional, 100_000e6);
        assertEq(pos.fixedRate, 0.05e18);
        assertEq(pos.margin, 10_000e6);
        assertTrue(pos.isActive);
        assertEq(pos.accumulatedPnL, 0);
    }

    function test_openPosition_ReceiveFixed_Success() public {
        vm.prank(bob);
        uint256 positionId = pm.openPosition(
            false,          // receive fixed
            50_000e6,
            0.06e18,
            180,
            5_000e6
        );

        PositionManager.Position memory pos = pm.getPosition(positionId);
        assertFalse(pos.isPayingFixed);
        assertEq(pos.notional, 50_000e6);
    }

    function test_openPosition_UpdatesTotals() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        assertEq(pm.totalFixedNotional(), 100_000e6);
        assertEq(pm.totalFloatingNotional(), 0);
        assertEq(pm.totalMargin(), 10_000e6);
        assertEq(pm.activePositionCount(), 1);

        vm.prank(bob);
        pm.openPosition(false, 50_000e6, 0.06e18, 90, 5_000e6);

        assertEq(pm.totalFixedNotional(), 100_000e6);
        assertEq(pm.totalFloatingNotional(), 50_000e6);
        assertEq(pm.totalMargin(), 15_000e6);
        assertEq(pm.activePositionCount(), 2);
    }

    function test_openPosition_TransfersMargin() public {
        uint256 balanceBefore = usdc.balanceOf(alice);
        uint256 notional = 100_000e6;
        uint256 margin = 10_000e6;

        // Calculate expected trading fee (0.05% of notional)
        uint256 tradingFee = pm.calculateTradingFee(notional);

        vm.prank(alice);
        pm.openPosition(true, uint128(notional), 0.05e18, 90, uint128(margin));

        // User pays margin + trading fee
        assertEq(usdc.balanceOf(alice), balanceBefore - margin - tradingFee);
        // Contract receives margin + fee (fee is accumulated separately)
        assertEq(usdc.balanceOf(address(pm)), margin + tradingFee);
    }

    function test_openPosition_EmitsEvent() public {
        vm.prank(alice);

        vm.expectEmit(true, true, true, true);
        emit PositionManager.PositionOpened(
            0,
            alice,
            true,
            100_000e6,
            0.05e18,
            10_000e6,
            block.timestamp + 90 days
        );

        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
    }

    function test_openPosition_AllMaturities() public {
        uint256[] memory maturities = new uint256[](4);
        maturities[0] = 30;
        maturities[1] = 90;
        maturities[2] = 180;
        maturities[3] = 365;

        for (uint256 i = 0; i < maturities.length; i++) {
            vm.prank(alice);
            uint256 positionId = pm.openPosition(
                true,
                100_000e6,
                0.05e18,
                maturities[i],
                10_000e6
            );

            PositionManager.Position memory pos = pm.getPosition(positionId);
            assertEq(pos.maturity, block.timestamp + maturities[i] * 1 days);
        }
    }

    /*//////////////////////////////////////////////////////////////
                      OPEN POSITION REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_openPosition_RevertZeroNotional() public {
        vm.prank(alice);
        vm.expectRevert(PositionManager.InvalidNotional.selector);
        pm.openPosition(true, 0, 0.05e18, 90, 10_000e6);
    }

    function test_openPosition_RevertZeroFixedRate() public {
        vm.prank(alice);
        vm.expectRevert(PositionManager.InvalidFixedRate.selector);
        pm.openPosition(true, 100_000e6, 0, 90, 10_000e6);
    }

    function test_openPosition_RevertExcessiveFixedRate() public {
        vm.prank(alice);
        vm.expectRevert(PositionManager.InvalidFixedRate.selector);
        pm.openPosition(true, 100_000e6, 1.01e18, 90, 10_000e6); // 101%
    }

    function test_openPosition_RevertInvalidMaturity() public {
        vm.prank(alice);
        vm.expectRevert(PositionManager.InvalidMaturity.selector);
        pm.openPosition(true, 100_000e6, 0.05e18, 45, 10_000e6); // 45 days not valid
    }

    function test_openPosition_RevertInsufficientMargin() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PositionManager.InsufficientMargin.selector,
                10_000e6, // required (10% of 100k)
                5_000e6   // provided
            )
        );
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 5_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                          ADD MARGIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addMargin_Success() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(alice);
        pm.addMargin(0, 5_000e6);

        PositionManager.Position memory pos = pm.getPosition(0);
        assertEq(pos.margin, 15_000e6);
        assertEq(pm.totalMargin(), 15_000e6);
    }

    function test_addMargin_AnyoneCanAdd() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Bob adds margin to Alice's position
        vm.prank(bob);
        pm.addMargin(0, 5_000e6);

        assertEq(pm.getMargin(0), 15_000e6);
    }

    function test_addMargin_EmitsEvent() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PositionManager.MarginAdded(0, alice, 5_000e6, 15_000e6);
        pm.addMargin(0, 5_000e6);
    }

    function test_addMargin_RevertZeroAmount() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(alice);
        vm.expectRevert(PositionManager.ZeroAmount.selector);
        pm.addMargin(0, 0);
    }

    function test_addMargin_RevertInactivePosition() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Close position
        vm.prank(settlement);
        pm.closePosition(0, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PositionManager.PositionNotActive.selector, 0));
        pm.addMargin(0, 5_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        REMOVE MARGIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_removeMargin_Success() public {
        // Open with extra margin
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 20_000e6); // 20% margin

        uint256 balanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        pm.removeMargin(0, 5_000e6);

        assertEq(pm.getMargin(0), 15_000e6);
        assertEq(usdc.balanceOf(alice), balanceBefore + 5_000e6);
    }

    function test_removeMargin_EmitsEvent() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 20_000e6);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PositionManager.MarginRemoved(0, alice, 5_000e6, 15_000e6);
        pm.removeMargin(0, 5_000e6);
    }

    function test_removeMargin_RevertNotOwner() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 20_000e6);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PositionManager.NotPositionOwner.selector, 0, bob));
        pm.removeMargin(0, 5_000e6);
    }

    function test_removeMargin_RevertExcessive() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6); // Exactly 10%

        // Try to remove 6k, leaving only 4k (below 5% min)
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PositionManager.ExcessiveMarginWithdrawal.selector,
                6_000e6,  // requested
                5_000e6   // available (margin - minMargin)
            )
        );
        pm.removeMargin(0, 6_000e6);
    }

    function test_removeMargin_RevertZeroAmount() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 20_000e6);

        vm.prank(alice);
        vm.expectRevert(PositionManager.ZeroAmount.selector);
        pm.removeMargin(0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                      CLOSE POSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_closePosition_PositivePnL() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Fund the contract with extra for profit payout (in production, comes from counterparty)
        usdc.mint(address(pm), 5_000e6);

        uint256 balanceBefore = usdc.balanceOf(alice);

        // Close with positive PnL
        vm.prank(settlement);
        pm.closePosition(0, 2_000e6); // $2k profit

        // Should receive margin + profit
        assertEq(usdc.balanceOf(alice), balanceBefore + 12_000e6);

        // Position should be inactive
        assertFalse(pm.getPosition(0).isActive);
        assertEq(pm.activePositionCount(), 0);
    }

    function test_closePosition_NegativePnL() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        uint256 balanceBefore = usdc.balanceOf(alice);

        // Close with negative PnL (loss)
        vm.prank(settlement);
        pm.closePosition(0, -3_000e6); // $3k loss

        // Should receive margin - loss
        assertEq(usdc.balanceOf(alice), balanceBefore + 7_000e6);
    }

    function test_closePosition_TotalLoss() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        uint256 balanceBefore = usdc.balanceOf(alice);

        // Close with total loss (exceeds margin)
        vm.prank(settlement);
        pm.closePosition(0, -15_000e6); // $15k loss > $10k margin

        // Should receive nothing
        assertEq(usdc.balanceOf(alice), balanceBefore);
    }

    function test_closePosition_UpdatesTotals() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(settlement);
        pm.closePosition(0, 0);

        assertEq(pm.totalFixedNotional(), 0);
        assertEq(pm.totalMargin(), 0);
        assertEq(pm.activePositionCount(), 0);
    }

    function test_closePosition_EmitsEvent() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Fund contract for payout
        usdc.mint(address(pm), 5_000e6);

        vm.prank(settlement);
        vm.expectEmit(true, true, true, true);
        // totalPnL = accumulatedPnL (0) + finalPnL (2_000e6) = 2_000e6
        // payout = margin (10_000e6) + totalPnL (2_000e6) = 12_000e6
        emit PositionManager.PositionClosed(0, alice, 2_000e6, 12_000e6);
        pm.closePosition(0, 2_000e6);
    }

    function test_closePosition_RevertNotAuthorized() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PositionManager.NotAuthorized.selector, alice));
        pm.closePosition(0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getTimeToMaturity() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        assertEq(pm.getTimeToMaturity(0), 90 days);

        // Advance time
        vm.warp(block.timestamp + 30 days);
        assertEq(pm.getTimeToMaturity(0), 60 days);

        // Past maturity
        vm.warp(block.timestamp + 100 days);
        assertEq(pm.getTimeToMaturity(0), 0);
    }

    function test_isMatured() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        assertFalse(pm.isMatured(0));

        vm.warp(block.timestamp + 90 days);
        assertTrue(pm.isMatured(0));
    }

    function test_calculateMinMargin() public view {
        assertEq(pm.calculateMinMargin(100_000e6), 10_000e6); // 10%
        assertEq(pm.calculateMinMargin(50_000e6), 5_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                      AUTHORIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setAuthorizedContract() public {
        address newContract = address(0x999);

        pm.setAuthorizedContract(newContract, true);
        assertTrue(pm.authorizedContracts(newContract));

        pm.setAuthorizedContract(newContract, false);
        assertFalse(pm.authorizedContracts(newContract));
    }

    function test_updatePositionPnL_OnlyAuthorized() public {
        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        vm.prank(settlement);
        pm.updatePositionPnL(0, 1_000e6);

        assertEq(pm.getPosition(0).accumulatedPnL, 1_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_openPosition_ValidInputs(
        uint256 notionalSeed,
        uint256 rateSeed,
        uint8 maturityIdx
    ) public {
        // Use bound instead of vm.assume for efficiency
        uint128 notional = uint128(bound(notionalSeed, 1000e6, 5_000_000e6));
        uint128 rate = uint128(bound(rateSeed, 0.001e18, 0.50e18));

        uint256[] memory maturities = new uint256[](4);
        maturities[0] = 30;
        maturities[1] = 90;
        maturities[2] = 180;
        maturities[3] = 365;
        uint256 maturity = maturities[maturityIdx % 4];

        uint128 margin = uint128((uint256(notional) * 15) / 100); // 15% margin

        vm.prank(alice);
        uint256 positionId = pm.openPosition(
            true,
            notional,
            rate,
            maturity,
            margin
        );

        assertTrue(pm.getPosition(positionId).isActive);
    }

    function testFuzz_marginOperations_Bounded(uint64 addAmount, uint64 removeAmount) public {
        vm.assume(addAmount > 0 && addAmount <= 100_000e6);

        vm.prank(alice);
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Add margin
        vm.prank(alice);
        pm.addMargin(0, uint128(addAmount));

        uint256 currentMargin = pm.getMargin(0);
        uint256 minMargin = 5_000e6; // 5% of 100k

        // Calculate max removable
        uint256 maxRemovable = currentMargin > minMargin ? currentMargin - minMargin : 0;

        if (removeAmount <= maxRemovable && removeAmount > 0) {
            vm.prank(alice);
            pm.removeMargin(0, uint128(removeAmount));
            assertTrue(pm.getMargin(0) >= minMargin);
        }
    }
}
