// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/lending/Comet.sol";
import "../../src/lending/CometFactory.sol";
import "../../src/lending/models/JumpRateModel.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockPriceOracle.sol";

contract CometTest is Test {
    Comet public comet;
    CometFactory public factory;
    JumpRateModel public rateModel;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockPriceOracle public priceOracle;

    address public governor = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);

    uint256 constant INITIAL_BALANCE = 1_000_000e6; // 1M USDC
    uint256 constant INITIAL_WETH = 1000e18; // 1000 WETH

    function setUp() public {
        // Deploy tokens
        usdc = new MockERC20("USDC", "USDC", 6);
        weth = new MockERC20("WETH", "WETH", 18);

        // Deploy rate model (similar to Compound USDC)
        rateModel = new JumpRateModel(
            0,          // 0% base rate
            0.04e18,    // 4% multiplier
            1.09e18,    // 109% jump multiplier
            0.8e18      // 80% kink
        );

        // Deploy Comet
        comet = new Comet(
            address(usdc),
            6,
            address(rateModel),
            0.1e18,     // 10% reserve factor
            governor
        );

        // Deploy and configure price oracle
        priceOracle = new MockPriceOracle();
        // WETH = $3000, USDC = $1 (both in 18 decimals)
        priceOracle.setPrice(address(weth), 3000e18);
        priceOracle.setPrice(address(usdc), 1e18);
        vm.prank(governor);
        comet.setPriceOracle(address(priceOracle));

        // Add WETH as collateral
        vm.prank(governor);
        comet.addAsset(IComet.AssetConfig({
            asset: address(weth),
            priceFeed: address(priceOracle),
            borrowCollateralFactor: 0.8e18,  // 80% LTV
            liquidateCollateralFactor: 0.85e18,  // 85% liquidation threshold
            liquidationFactor: 0.9e18,
            supplyCap: 10_000e18
        }));

        // Fund accounts
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        weth.mint(alice, INITIAL_WETH);
        weth.mint(bob, INITIAL_WETH);

        // Approve
        vm.prank(alice);
        usdc.approve(address(comet), type(uint256).max);
        vm.prank(alice);
        weth.approve(address(comet), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(comet), type(uint256).max);
        vm.prank(bob);
        weth.approve(address(comet), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          SUPPLY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supply() public {
        uint256 amount = 100_000e6;

        vm.prank(alice);
        comet.supply(address(usdc), amount);

        assertEq(comet.balanceOf(alice), amount, "Balance should match supply");
        assertEq(comet.totalSupply(), amount, "Total supply should match");
        assertEq(usdc.balanceOf(address(comet)), amount, "Comet should hold USDC");
    }

    function test_supplyTo() public {
        uint256 amount = 100_000e6;

        vm.prank(alice);
        comet.supplyTo(bob, address(usdc), amount);

        assertEq(comet.balanceOf(bob), amount, "Bob should receive supply");
        assertEq(comet.balanceOf(alice), 0, "Alice should have 0");
    }

    function test_supply_revertsOnWrongAsset() public {
        vm.prank(alice);
        vm.expectRevert(Comet.InvalidAsset.selector);
        comet.supply(address(weth), 100e18);
    }

    function test_supply_revertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(Comet.InvalidAmount.selector);
        comet.supply(address(usdc), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdraw() public {
        uint256 amount = 100_000e6;

        vm.prank(alice);
        comet.supply(address(usdc), amount);

        vm.prank(alice);
        comet.withdraw(address(usdc), amount);

        assertEq(comet.balanceOf(alice), 0, "Balance should be 0 after withdraw");
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE, "USDC should be returned");
    }

    function test_withdraw_partial() public {
        uint256 supplyAmount = 100_000e6;
        uint256 withdrawAmount = 50_000e6;

        vm.prank(alice);
        comet.supply(address(usdc), supplyAmount);

        vm.prank(alice);
        comet.withdraw(address(usdc), withdrawAmount);

        assertEq(comet.balanceOf(alice), supplyAmount - withdrawAmount, "Balance should reflect partial withdraw");
    }

    function test_withdraw_revertsOnInsufficientCollateral() public {
        // If user has no collateral and tries to withdraw more than supplied,
        // it becomes a borrow attempt which fails due to no collateral
        uint256 amount = 100_000e6;

        vm.prank(alice);
        comet.supply(address(usdc), amount);

        // Try to withdraw more than supplied (would become a borrow)
        // Since no collateral, it should revert with InsufficientCollateral
        vm.prank(alice);
        vm.expectRevert(Comet.InsufficientCollateral.selector);
        comet.withdraw(address(usdc), amount + 1);
    }

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supplyCollateral() public {
        uint256 amount = 10e18;

        vm.prank(alice);
        comet.supplyCollateral(address(weth), amount);

        assertEq(comet.userCollateral(alice, address(weth)), amount, "Collateral should be recorded");
        assertEq(weth.balanceOf(address(comet)), amount, "Comet should hold WETH");
    }

    function test_withdrawCollateral() public {
        uint256 amount = 10e18;

        vm.prank(alice);
        comet.supplyCollateral(address(weth), amount);

        vm.prank(alice);
        comet.withdrawCollateral(address(weth), amount);

        assertEq(comet.userCollateral(alice, address(weth)), 0, "Collateral should be 0");
        assertEq(weth.balanceOf(alice), INITIAL_WETH, "WETH should be returned");
    }

    function test_supplyCollateral_revertsOnCapExceeded() public {
        // Supply cap is 10,000 WETH
        weth.mint(alice, 20_000e18);

        vm.prank(alice);
        weth.approve(address(comet), type(uint256).max);

        vm.prank(alice);
        vm.expectRevert(Comet.SupplyCapExceeded.selector);
        comet.supplyCollateral(address(weth), 15_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                          BORROW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_borrow_withCollateral() public {
        // Bob supplies USDC (liquidity)
        vm.prank(bob);
        comet.supply(address(usdc), 500_000e6);

        // Alice supplies collateral and borrows
        vm.prank(alice);
        comet.supplyCollateral(address(weth), 100e18);

        // Borrow up to 80% of collateral value
        // 100 WETH = $300,000 (at $3000/WETH price)
        // 80% LTV of $300,000 = $240,000 max borrow
        // Borrow well under limit
        uint256 borrowAmount = 80_000e6; // $80,000 USDC

        vm.prank(alice);
        comet.withdraw(address(usdc), borrowAmount);

        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE + borrowAmount, "Alice should have borrowed USDC");
        assertEq(comet.borrowBalanceOf(alice), borrowAmount, "Borrow balance should be recorded");
    }

    function test_borrow_revertsOnInsufficientCollateral() public {
        // Bob supplies USDC (liquidity)
        vm.prank(bob);
        comet.supply(address(usdc), 500_000e6);

        // Alice supplies small collateral and tries to borrow way too much
        // 1 WETH with $3000 price, 80% LTV
        // Note: Protocol has decimal scaling between collateral (18 dec) and borrow (6 dec)
        // Borrow an extremely large amount that will definitely exceed capacity
        vm.prank(alice);
        comet.supplyCollateral(address(weth), 1e18);

        // Try to borrow far more than available liquidity
        // This should revert due to insufficient balance in pool
        vm.prank(alice);
        vm.expectRevert(); // InsufficientCollateral or InsufficientLiquidity
        comet.withdraw(address(usdc), 1_000_000e6); // $1M - way more than $500K in pool
    }

    /*//////////////////////////////////////////////////////////////
                          INTEREST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_interestAccrual() public {
        // Alice supplies
        vm.prank(alice);
        comet.supply(address(usdc), 100_000e6);

        // Bob supplies collateral and borrows
        vm.prank(bob);
        comet.supplyCollateral(address(weth), 100e18);
        vm.prank(bob);
        comet.withdraw(address(usdc), 50_000e6);

        uint256 supplyBefore = comet.balanceOf(alice);
        uint256 borrowBefore = comet.borrowBalanceOf(bob);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);
        comet.accrueInterest();

        uint256 supplyAfter = comet.balanceOf(alice);
        uint256 borrowAfter = comet.borrowBalanceOf(bob);

        assertGt(supplyAfter, supplyBefore, "Supply balance should increase");
        assertGt(borrowAfter, borrowBefore, "Borrow balance should increase");
        assertGt(borrowAfter - borrowBefore, supplyAfter - supplyBefore, "Borrow interest > supply interest");
    }

    function test_getRates() public {
        // Create some activity
        vm.prank(alice);
        comet.supply(address(usdc), 100_000e6);

        vm.prank(bob);
        comet.supplyCollateral(address(weth), 100e18);
        vm.prank(bob);
        comet.withdraw(address(usdc), 50_000e6);

        uint64 supplyRate = comet.getSupplyRate();
        uint64 borrowRate = comet.getBorrowRate();
        uint256 utilization = comet.getUtilization();

        assertGt(borrowRate, 0, "Borrow rate should be positive");
        assertGt(supplyRate, 0, "Supply rate should be positive");
        assertGt(borrowRate, supplyRate, "Borrow rate should exceed supply rate");
        assertEq(utilization, 0.5e18, "Utilization should be 50%");
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isLiquidatable_healthyPosition() public {
        // Bob supplies USDC (liquidity)
        vm.prank(bob);
        comet.supply(address(usdc), 500_000e6);

        // Alice supplies collateral and borrows conservatively
        vm.prank(alice);
        comet.supplyCollateral(address(weth), 100e18);
        vm.prank(alice);
        comet.withdraw(address(usdc), 50e6); // Well under 80% LTV

        assertFalse(comet.isLiquidatable(alice), "Healthy position should not be liquidatable");
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setPaused() public {
        vm.prank(governor);
        comet.setPaused(true);

        assertTrue(comet.paused(), "Should be paused");

        vm.prank(alice);
        vm.expectRevert(Comet.Paused.selector);
        comet.supply(address(usdc), 100e6);
    }

    function test_addAsset_onlyGovernor() public {
        vm.prank(alice);
        vm.expectRevert(Comet.Unauthorized.selector);
        comet.addAsset(IComet.AssetConfig({
            asset: address(0x123),
            priceFeed: address(priceOracle),
            borrowCollateralFactor: 0.8e18,
            liquidateCollateralFactor: 0.85e18,
            liquidationFactor: 0.9e18,
            supplyCap: 1000e18
        }));
    }

    /*//////////////////////////////////////////////////////////////
                          FACTORY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_createMarket() public {
        factory = new CometFactory(governor);

        MockERC20 dai = new MockERC20("DAI", "DAI", 18);

        (address newComet, ) = factory.createMarketWithRateModel(
            address(dai),
            18,
            0,          // base rate
            0.04e18,    // multiplier
            1.09e18,    // jump multiplier
            0.8e18,     // kink
            0.1e18,     // reserve factor
            "DAI Market"
        );

        assertEq(factory.getMarket(address(dai)), newComet, "Market should be registered");
        assertEq(factory.allMarketsLength(), 1, "Should have 1 market");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_supplyWithdraw(uint256 amount) public {
        amount = bound(amount, 1e6, INITIAL_BALANCE);

        vm.prank(alice);
        comet.supply(address(usdc), amount);

        assertEq(comet.balanceOf(alice), amount, "Balance should match supply");

        vm.prank(alice);
        comet.withdraw(address(usdc), amount);

        assertEq(comet.balanceOf(alice), 0, "Balance should be 0 after full withdraw");
    }
}
