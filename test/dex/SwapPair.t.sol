// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/dex/core/SwapFactory.sol";
import "../../src/dex/core/SwapPair.sol";
import "../../src/dex/periphery/SwapRouter.sol";
import "../../src/mocks/MockERC20.sol";

contract SwapPairTest is Test {
    SwapFactory public factory;
    SwapRouter public router;
    SwapPair public pair;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public weth;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public feeRecipient = address(0x3);

    uint256 constant INITIAL_BALANCE = 1_000_000e18;

    function setUp() public {
        // Deploy tokens
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);
        weth = new MockERC20("WETH", "WETH", 18);

        // Deploy factory and router
        factory = new SwapFactory(address(this));
        router = new SwapRouter(address(factory), address(weth));

        // Create pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = SwapPair(pairAddress);

        // Fund accounts
        tokenA.mint(alice, INITIAL_BALANCE);
        tokenB.mint(alice, INITIAL_BALANCE);
        tokenA.mint(bob, INITIAL_BALANCE);
        tokenB.mint(bob, INITIAL_BALANCE);

        // Approve router
        vm.startPrank(alice);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          FACTORY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_createPair() public view {
        assertEq(factory.allPairsLength(), 1, "Should have 1 pair");
        assertEq(factory.getPair(address(tokenA), address(tokenB)), address(pair), "Pair should be registered");
        assertEq(factory.getPair(address(tokenB), address(tokenA)), address(pair), "Reverse lookup should work");
    }

    function test_factory_createPair_revertsOnDuplicate() public {
        vm.expectRevert("SwapFactory: PAIR_EXISTS");
        factory.createPair(address(tokenA), address(tokenB));
    }

    function test_factory_createPair_revertsOnIdentical() public {
        vm.expectRevert("SwapFactory: IDENTICAL_ADDRESSES");
        factory.createPair(address(tokenA), address(tokenA));
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addLiquidity_initial() public {
        uint256 amountA = 10_000e18;
        uint256 amountB = 20_000e18;

        vm.prank(alice);
        (uint256 actualA, uint256 actualB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        assertEq(actualA, amountA, "Should add exact amountA");
        assertEq(actualB, amountB, "Should add exact amountB");
        assertGt(liquidity, 0, "Should receive LP tokens");

        // Check reserves
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertGt(reserve0, 0, "Reserve0 should be positive");
        assertGt(reserve1, 0, "Reserve1 should be positive");
    }

    function test_addLiquidity_subsequent() public {
        // Initial liquidity
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10_000e18,
            20_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        // Bob adds more liquidity
        vm.prank(bob);
        (uint256 actualA, uint256 actualB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            5_000e18,
            10_000e18,
            0,
            0,
            bob,
            block.timestamp + 1 hours
        );

        assertGt(liquidity, 0, "Bob should receive LP tokens");
        assertGt(pair.balanceOf(bob), 0, "Bob should have LP balance");
    }

    function test_removeLiquidity() public {
        // Add liquidity first
        vm.prank(alice);
        (,, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10_000e18,
            20_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        // Approve LP tokens
        vm.prank(alice);
        pair.approve(address(router), liquidity);

        uint256 balanceABefore = tokenA.balanceOf(alice);
        uint256 balanceBBefore = tokenB.balanceOf(alice);

        // Remove liquidity
        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        assertGt(amountA, 0, "Should receive tokenA");
        assertGt(amountB, 0, "Should receive tokenB");
        assertEq(pair.balanceOf(alice), 0, "LP balance should be 0");
        assertEq(tokenA.balanceOf(alice), balanceABefore + amountA, "TokenA should increase");
        assertEq(tokenB.balanceOf(alice), balanceBBefore + amountB, "TokenB should increase");
    }

    /*//////////////////////////////////////////////////////////////
                          SWAP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_swap_exactTokensForTokens() public {
        // Add liquidity first
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        // Bob swaps
        uint256 amountIn = 1_000e18;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 balanceBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            bob,
            block.timestamp + 1 hours
        );

        assertEq(amounts[0], amountIn, "Input amount should match");
        assertGt(amounts[1], 0, "Output amount should be positive");
        assertEq(tokenB.balanceOf(bob), balanceBefore + amounts[1], "Balance should increase");
    }

    function test_swap_tokensForExactTokens() public {
        // Add liquidity first
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        // Bob swaps for exact output
        uint256 amountOut = 1_000e18;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 balanceABefore = tokenA.balanceOf(bob);
        uint256 balanceBBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            type(uint256).max,
            path,
            bob,
            block.timestamp + 1 hours
        );

        assertGt(amounts[0], 0, "Input amount should be positive");
        assertEq(amounts[1], amountOut, "Output amount should match exact");
        assertEq(tokenA.balanceOf(bob), balanceABefore - amounts[0], "TokenA should decrease");
        assertEq(tokenB.balanceOf(bob), balanceBBefore + amountOut, "TokenB should increase by exact amount");
    }

    /*//////////////////////////////////////////////////////////////
                          K INVARIANT TEST
    //////////////////////////////////////////////////////////////*/

    function test_swap_maintainsKInvariant() public {
        // Add liquidity
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        (uint112 reserveA_before, uint112 reserveB_before,) = pair.getReserves();
        uint256 k_before = uint256(reserveA_before) * uint256(reserveB_before);

        // Swap
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.prank(bob);
        router.swapExactTokensForTokens(
            1_000e18,
            0,
            path,
            bob,
            block.timestamp + 1 hours
        );

        (uint112 reserveA_after, uint112 reserveB_after,) = pair.getReserves();
        uint256 k_after = uint256(reserveA_after) * uint256(reserveB_after);

        // K should increase or stay same (due to fees)
        assertGe(k_after, k_before, "K should not decrease after swap");
    }

    /*//////////////////////////////////////////////////////////////
                          SLIPPAGE PROTECTION
    //////////////////////////////////////////////////////////////*/

    function test_swap_revertsOnInsufficientOutput() public {
        // Add liquidity
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // Expect too much output
        vm.prank(bob);
        vm.expectRevert(SwapRouter.InsufficientOutputAmount.selector);
        router.swapExactTokensForTokens(
            1_000e18,
            2_000e18, // Impossible output amount
            path,
            bob,
            block.timestamp + 1 hours
        );
    }

    function test_swap_revertsOnExpiredDeadline() public {
        // Add liquidity
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // Set deadline in the past
        vm.prank(bob);
        vm.expectRevert(SwapRouter.Expired.selector);
        router.swapExactTokensForTokens(
            1_000e18,
            0,
            path,
            bob,
            block.timestamp - 1 // Expired
        );
    }

    /*//////////////////////////////////////////////////////////////
                            QUOTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAmountOut() public {
        // Add liquidity
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        (uint112 reserveA, uint112 reserveB,) = pair.getReserves();

        // Get quote
        address token0 = pair.token0();
        (uint256 reserveIn, uint256 reserveOut) = address(tokenA) == token0
            ? (uint256(reserveA), uint256(reserveB))
            : (uint256(reserveB), uint256(reserveA));

        uint256 amountOut = router.getAmountOut(1_000e18, reserveIn, reserveOut);
        assertGt(amountOut, 0, "Amount out should be positive");
        assertLt(amountOut, 1_000e18, "Amount out should be less than input (due to fee)");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_swap_alwaysMaintainsK(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 10_000e18);

        // Add liquidity
        vm.prank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100_000e18,
            100_000e18,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        (uint112 r0_before, uint112 r1_before,) = pair.getReserves();
        uint256 k_before = uint256(r0_before) * uint256(r1_before);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.prank(bob);
        router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            bob,
            block.timestamp + 1 hours
        );

        (uint112 r0_after, uint112 r1_after,) = pair.getReserves();
        uint256 k_after = uint256(r0_after) * uint256(r1_after);

        assertGe(k_after, k_before, "K invariant must hold");
    }
}
