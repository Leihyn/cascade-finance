// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

// Lending SDK
import "../../src/lending/Comet.sol";
import "../../src/lending/CometFactory.sol";
import "../../src/lending/models/JumpRateModel.sol";

// DEX SDK
import "../../src/dex/core/SwapFactory.sol";
import "../../src/dex/core/SwapPair.sol";
import "../../src/dex/periphery/SwapRouter.sol";

// IRS Protocol
import "../../src/adapters/CometRateAdapter.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/core/PositionManager.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/risk/MarginEngine.sol";

// Mocks
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockPriceOracle.sol";

/// @title FullStackTest
/// @notice Integration test demonstrating the complete DeFi stack
/// @dev Tests: Lending SDK → CometRateAdapter → RateOracle → IRS Protocol
contract FullStackTest is Test {
    // Lending SDK
    CometFactory public cometFactory;
    Comet public comet;
    JumpRateModel public rateModel;
    CometRateAdapter public rateAdapter;

    // DEX SDK
    SwapFactory public swapFactory;
    SwapRouter public swapRouter;

    // IRS Protocol
    RateOracle public oracle;
    PositionManager public positionManager;
    SettlementEngine public settlementEngine;
    MarginEngine public marginEngine;

    // Tokens
    MockERC20 public usdc;
    MockERC20 public weth;

    // Oracles
    MockPriceOracle public priceOracle;

    // Actors
    address public governor = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public feeRecipient = address(0x4);

    function setUp() public {
        // Deploy tokens
        usdc = new MockERC20("USDC", "USDC", 6);
        weth = new MockERC20("WETH", "WETH", 18);

        // =====================================================
        // Deploy Lending SDK
        // =====================================================
        cometFactory = new CometFactory(governor);

        // Create rate model (typical USDC parameters)
        rateModel = new JumpRateModel(
            0,          // 0% base rate
            0.04e18,    // 4% multiplier (rate at 100% util below kink)
            1.09e18,    // 109% jump multiplier (rate increase above kink)
            0.8e18      // 80% kink
        );

        // Create USDC market
        comet = new Comet(
            address(usdc),
            6,
            address(rateModel),
            0.1e18,     // 10% reserve factor
            governor
        );

        // Deploy and configure price oracle
        priceOracle = new MockPriceOracle();
        priceOracle.setPrice(address(weth), 3000e18);  // WETH = $3000
        priceOracle.setPrice(address(usdc), 1e18);     // USDC = $1
        vm.prank(governor);
        comet.setPriceOracle(address(priceOracle));

        // Add WETH as collateral
        vm.prank(governor);
        comet.addAsset(IComet.AssetConfig({
            asset: address(weth),
            priceFeed: address(priceOracle),
            borrowCollateralFactor: 0.8e18,
            liquidateCollateralFactor: 0.85e18,
            liquidationFactor: 0.9e18,
            supplyCap: 100_000e18
        }));

        // =====================================================
        // Deploy DEX SDK
        // =====================================================
        swapFactory = new SwapFactory(governor);
        swapRouter = new SwapRouter(address(swapFactory), address(weth));

        // Create USDC/WETH pair
        swapFactory.createPair(address(usdc), address(weth));

        // =====================================================
        // Deploy IRS Protocol with Comet Rate Adapter
        // =====================================================
        rateAdapter = new CometRateAdapter(address(comet));

        // Create rate oracle with our adapter
        address[] memory sources = new address[](1);
        sources[0] = address(rateAdapter);
        oracle = new RateOracle(sources, 1, 1 hours);

        // Deploy IRS components
        positionManager = new PositionManager(address(usdc), 6, feeRecipient);
        marginEngine = new MarginEngine(address(positionManager), address(oracle));

        // =====================================================
        // Fund test accounts
        // =====================================================
        usdc.mint(alice, 10_000_000e6);  // 10M USDC
        usdc.mint(bob, 10_000_000e6);
        weth.mint(alice, 10_000e18);     // 10K WETH
        weth.mint(bob, 10_000e18);

        // Approve contracts
        vm.startPrank(alice);
        usdc.approve(address(comet), type(uint256).max);
        usdc.approve(address(swapRouter), type(uint256).max);
        usdc.approve(address(positionManager), type(uint256).max);
        weth.approve(address(comet), type(uint256).max);
        weth.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(comet), type(uint256).max);
        usdc.approve(address(swapRouter), type(uint256).max);
        usdc.approve(address(positionManager), type(uint256).max);
        weth.approve(address(comet), type(uint256).max);
        weth.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    FULL STACK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test complete flow: Supply to lending → rates feed IRS → open position
    function test_fullStack_lendingToIRS() public {
        // =====================================================
        // Step 1: Alice supplies USDC to lending pool
        // =====================================================
        vm.prank(alice);
        comet.supply(address(usdc), 1_000_000e6);

        // Verify supply
        assertEq(comet.balanceOf(alice), 1_000_000e6, "Alice should have supply balance");

        // =====================================================
        // Step 2: Bob supplies collateral and borrows
        // =====================================================
        vm.startPrank(bob);
        comet.supplyCollateral(address(weth), 1000e18);
        comet.withdraw(address(usdc), 500_000e6);  // 50% LTV
        vm.stopPrank();

        // Verify borrow
        assertGt(comet.borrowBalanceOf(bob), 0, "Bob should have borrow balance");

        // =====================================================
        // Step 3: Check that rates are now non-zero
        // =====================================================
        uint64 supplyRate = comet.getSupplyRate();
        uint64 borrowRate = comet.getBorrowRate();

        assertGt(supplyRate, 0, "Supply rate should be positive with borrows");
        assertGt(borrowRate, 0, "Borrow rate should be positive");

        // =====================================================
        // Step 4: Verify rate adapter correctly annualizes rates
        // =====================================================
        uint256 annualSupplyRate = rateAdapter.getSupplyRate();
        uint256 annualBorrowRate = rateAdapter.getBorrowRate();

        assertGt(annualSupplyRate, 0, "Annual supply rate should be positive");
        assertGt(annualBorrowRate, annualSupplyRate, "Borrow rate should exceed supply rate");

        // Verify annualization (rate * seconds_per_year)
        assertEq(annualSupplyRate, uint256(supplyRate) * 365 days, "Should be correctly annualized");

        // =====================================================
        // Step 5: Open IRS position using rates from lending pool
        // =====================================================
        // Get current rate for fixed rate
        uint256 currentRate = oracle.getCurrentRate();

        // Alice opens a pay-fixed position (bets rates will rise)
        vm.prank(alice);
        uint256 positionId = positionManager.openPosition(
            true,           // Pay fixed
            1_000_000e6,    // 1M notional
            uint128(currentRate),  // Lock in current rate
            90,             // 90 days maturity
            100_000e6       // 100K margin
        );

        // Verify position (positionId starts at 0)
        assertEq(positionManager.ownerOf(positionId), alice, "Alice should own the position");
        assertEq(positionManager.activePositionCount(), 1, "Should have 1 active position");
    }

    /// @notice Test that interest accrual in lending affects IRS rates
    function test_fullStack_rateChanges() public {
        // Initial state: No borrows
        uint256 initialRate = rateAdapter.getSupplyRate();
        assertEq(initialRate, 0, "Initial rate should be 0 with no borrows");

        // Alice supplies
        vm.prank(alice);
        comet.supply(address(usdc), 2_000_000e6);

        // Bob creates demand by borrowing
        vm.startPrank(bob);
        comet.supplyCollateral(address(weth), 2000e18);
        comet.withdraw(address(usdc), 800_000e6);  // 40% utilization
        vm.stopPrank();

        uint256 rateAt40 = rateAdapter.getSupplyRate();
        assertGt(rateAt40, 0, "Rate should be positive at 40% util");

        // More borrowing increases rates
        vm.prank(bob);
        comet.withdraw(address(usdc), 800_000e6);  // Now 80% utilization (at kink)

        uint256 rateAt80 = rateAdapter.getSupplyRate();
        assertGt(rateAt80, rateAt40, "Rate should increase with utilization");
    }

    /// @notice Test DEX provides liquidity for trading
    function test_fullStack_dexLiquidity() public {
        // Add liquidity to DEX
        vm.prank(alice);
        swapRouter.addLiquidity(
            address(usdc),
            address(weth),
            100_000e6,   // 100K USDC
            50e18,       // 50 WETH (2000 USDC/WETH implied price)
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );

        // Verify pair has liquidity
        address pair = swapFactory.getPair(address(usdc), address(weth));
        (uint112 reserve0, uint112 reserve1,) = SwapPair(pair).getReserves();
        assertGt(reserve0, 0, "Should have reserve0");
        assertGt(reserve1, 0, "Should have reserve1");

        // Bob can swap
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);

        uint256 wethBefore = weth.balanceOf(bob);

        vm.prank(bob);
        swapRouter.swapExactTokensForTokens(
            10_000e6,  // 10K USDC
            0,
            path,
            bob,
            block.timestamp + 1 hours
        );

        assertGt(weth.balanceOf(bob), wethBefore, "Bob should receive WETH");
    }

    /// @notice Test the complete composability story
    function test_fullStack_composability() public {
        // =====================================================
        // 1. Supply liquidity to lending pool
        // =====================================================
        vm.prank(alice);
        comet.supply(address(usdc), 5_000_000e6);

        // =====================================================
        // 2. Supply liquidity to DEX
        // =====================================================
        vm.prank(alice);
        swapRouter.addLiquidity(
            address(usdc),
            address(weth),
            500_000e6,
            250e18,
            0, 0,
            alice,
            block.timestamp + 1 hours
        );

        // =====================================================
        // 3. Borrow from lending to create rate activity
        // =====================================================
        vm.startPrank(bob);
        comet.supplyCollateral(address(weth), 5000e18);
        comet.withdraw(address(usdc), 2_500_000e6);  // 50% util
        vm.stopPrank();

        // =====================================================
        // 4. Open IRS position based on lending rates
        // =====================================================
        uint256 currentRate = oracle.getCurrentRate();

        vm.prank(alice);
        uint256 positionId = positionManager.openPosition(
            false,          // Receive fixed (bets rates will fall)
            2_000_000e6,    // 2M notional
            uint128(currentRate),
            180,            // 180 days
            200_000e6       // 200K margin
        );

        // =====================================================
        // 5. Verify everything works together
        // =====================================================

        // Lending pool has activity
        assertGt(comet.totalSupply(), 0);
        assertGt(comet.totalBorrow(), 0);

        // DEX has liquidity
        address pair = swapFactory.getPair(address(usdc), address(weth));
        assertGt(SwapPair(pair).totalSupply(), 0);

        // IRS has position fed by lending rates
        assertEq(positionManager.ownerOf(positionId), alice);
        assertEq(positionManager.activePositionCount(), 1);

        // Rate adapter provides valid rates
        (uint256 supplyRate, uint256 borrowRate) = rateAdapter.getRates();
        assertGt(supplyRate, 0);
        assertGt(borrowRate, 0);
    }
}
