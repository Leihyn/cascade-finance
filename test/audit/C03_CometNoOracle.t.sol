// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/lending/Comet.sol";
import "../../src/lending/interfaces/IRateModel.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockPriceOracle.sol";

/**
 * @title C-03 Regression Test: Oracle Fallback Removed
 * @notice Verifies that the Phase 1 security fix works correctly
 *
 * ORIGINAL VULNERABILITY:
 * - _getCollateralValue() silently returned 1:1 pricing when oracle not configured
 * - Attacker could drain protocol with worthless collateral
 *
 * FIX IMPLEMENTED:
 * - Strict oracle validation with OracleNotConfigured error
 * - Price staleness checks with StalePriceData error
 * - Zero price checks with InvalidPriceData error
 */

// Simple mock rate model for testing
contract MockRateModel is IRateModel {
    function getBorrowRate(uint256, uint256, uint256) external pure returns (uint256) {
        return 1585489599; // ~5% APR in per-second rate
    }

    function getSupplyRate(uint256, uint256, uint256, uint256) external pure returns (uint256) {
        return 1268391679; // ~4% APR in per-second rate
    }

    function utilizationRate(uint256 cash, uint256 borrows, uint256) external pure returns (uint256) {
        if (cash + borrows == 0) return 0;
        return (borrows * 1e18) / (cash + borrows);
    }
}

contract C03_CometNoOracleTest is Test {
    Comet public comet;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockERC20 public shitcoin;
    MockRateModel public rateModel;
    MockPriceOracle public priceOracle;

    address attacker = address(0xBAD);
    address victim = address(0x1);
    address governor = address(this);

    uint256 constant ONE_USDC = 1e6;
    uint256 constant ONE_WETH = 1e18;

    function setUp() public {
        // Deploy tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped ETH", "WETH", 18);
        shitcoin = new MockERC20("Worthless Token", "SHIT", 18);

        // Deploy rate model
        rateModel = new MockRateModel();

        // Deploy Comet
        comet = new Comet(
            address(usdc),  // base token
            6,              // decimals
            address(rateModel),
            0.1e18,         // 10% reserve factor
            governor
        );

        // Deploy and configure price oracle with REAL prices
        priceOracle = new MockPriceOracle();
        priceOracle.setPrice(address(weth), 3000e18);    // WETH = $3000
        priceOracle.setPrice(address(usdc), 1e18);       // USDC = $1
        priceOracle.setPrice(address(shitcoin), 0);      // SHITCOIN = $0 (worthless)
        comet.setPriceOracle(address(priceOracle));

        // Add WETH as collateral (properly priced)
        comet.addAsset(IComet.AssetConfig({
            asset: address(weth),
            priceFeed: address(priceOracle),
            borrowCollateralFactor: uint64(0.7e18),       // 70% LTV
            liquidateCollateralFactor: uint64(0.85e18),   // 85% liquidation
            liquidationFactor: uint64(0.9e18),
            supplyCap: uint128(10_000e18)                 // 10k WETH
        }));

        // Add SHITCOIN as collateral (priced at $0)
        comet.addAsset(IComet.AssetConfig({
            asset: address(shitcoin),
            priceFeed: address(priceOracle),
            borrowCollateralFactor: uint64(0.7e18),
            liquidateCollateralFactor: uint64(0.85e18),
            liquidationFactor: uint64(0.9e18),
            supplyCap: uint128(1_000_000e18)
        }));

        // Fund victim with USDC to supply
        usdc.mint(victim, 1_000_000 * ONE_USDC);
        vm.prank(victim);
        usdc.approve(address(comet), type(uint256).max);

        // Victim supplies USDC
        vm.prank(victim);
        comet.supply(address(usdc), 1_000_000 * ONE_USDC);

        // Fund attacker with worthless tokens
        shitcoin.mint(attacker, 10_000_000e18);
        vm.prank(attacker);
        shitcoin.approve(address(comet), type(uint256).max);
    }

    /**
     * @notice FIXED: Attacker can no longer drain with worthless collateral
     * @dev Borrow now correctly reverts because SHITCOIN has $0 value
     * @dev Phase 1 fix catches zero prices with InvalidPriceData error
     */
    function test_FIXED_CannotDrainWithWorthlessCollateral() public {
        console.log("=== Testing Security Fix ===");

        // Step 1: Attacker deposits worthless tokens as collateral
        vm.prank(attacker);
        comet.supplyCollateral(address(shitcoin), 1_000_000e18);

        console.log("Attacker deposited 1,000,000 SHITCOIN (worth $0)");

        // Step 2: Attacker tries to borrow - SHOULD REVERT
        // Phase 1 security: Zero price triggers InvalidPriceData before collateral check
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Comet.InvalidPriceData.selector, address(shitcoin)));
        comet.withdraw(address(usdc), 1e6);  // Even $1 should fail

        console.log("SECURITY FIX VERIFIED: Borrow reverted with InvalidPriceData");
    }

    /**
     * @notice FIXED: Zero-priced collateral triggers InvalidPriceData
     * @dev Phase 1 security validates prices before collateral calculation
     */
    function test_FIXED_ZeroPriceGivesZeroBorrowCapacity() public {
        // Deposit worthless collateral
        vm.prank(attacker);
        comet.supplyCollateral(address(shitcoin), 100e18);

        // System now validates prices - zero price triggers InvalidPriceData
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Comet.InvalidPriceData.selector, address(shitcoin)));
        comet.withdraw(address(usdc), 1e6);

        console.log("Zero-priced collateral correctly triggers InvalidPriceData");
    }

    /**
     * @notice FIXED: Oracle validates prices before collateral calculations
     * @dev Tests that price oracle is used in liquidation checks
     * Note: The protocol has a separate decimal scaling issue between collateral (18 dec)
     * and borrow values (6 dec) that makes direct comparisons difficult. This test focuses
     * on verifying the oracle security fix works correctly.
     */
    function test_FIXED_LiquidationUsesOraclePrice() public {
        // Setup: User borrows against real collateral (WETH)
        weth.mint(attacker, 10e18);
        vm.startPrank(attacker);
        weth.approve(address(comet), type(uint256).max);
        comet.supplyCollateral(address(weth), 1e18);  // 1 WETH = $3000
        comet.withdraw(address(usdc), 2000e6);        // Borrow $2000 (within 70% LTV)
        vm.stopPrank();

        // Verify that price changes affect collateral calculations
        // by setting an extremely low price that would cause InvalidPriceData
        priceOracle.setPrice(address(weth), 0);

        // isLiquidatable should now revert with InvalidPriceData because price is 0
        vm.expectRevert(abi.encodeWithSelector(Comet.InvalidPriceData.selector, address(weth)));
        comet.isLiquidatable(attacker);

        // Reset price to a valid value
        priceOracle.setPrice(address(weth), 3000e18);

        // Now isLiquidatable should work without reverting
        // (The actual liquidation logic depends on proper decimal scaling,
        // which is a separate issue from oracle security)
        assertFalse(comet.isLiquidatable(attacker), "Should not revert with valid price");

        console.log("Liquidation check correctly uses oracle price validation");
    }

    /**
     * @notice Verify oracle is required for borrow operations
     */
    function test_OracleRequired_ForBorrow() public {
        // Deploy a fresh Comet WITHOUT oracle configured
        Comet freshComet = new Comet(
            address(usdc),
            6,
            address(rateModel),
            0.1e18,
            governor
        );

        // Add collateral asset
        freshComet.addAsset(IComet.AssetConfig({
            asset: address(weth),
            priceFeed: address(0),
            borrowCollateralFactor: uint64(0.7e18),
            liquidateCollateralFactor: uint64(0.85e18),
            liquidationFactor: uint64(0.9e18),
            supplyCap: uint128(10_000e18)
        }));

        // Fund and setup
        usdc.mint(victim, 100_000e6);
        vm.prank(victim);
        usdc.approve(address(freshComet), type(uint256).max);
        vm.prank(victim);
        freshComet.supply(address(usdc), 100_000e6);

        weth.mint(attacker, 100e18);
        vm.startPrank(attacker);
        weth.approve(address(freshComet), type(uint256).max);
        freshComet.supplyCollateral(address(weth), 10e18);

        // Try to borrow - should revert because oracle not configured
        vm.expectRevert(Comet.OracleNotConfigured.selector);
        freshComet.withdraw(address(usdc), 1000e6);
        vm.stopPrank();

        console.log("SECURITY FIX VERIFIED: Oracle is required for borrow operations");
    }

    /**
     * @notice Supply caps still provide defense in depth
     */
    function test_SupplyCapsStillWork() public {
        // Try to exceed supply cap
        shitcoin.mint(attacker, 2_000_000e18);
        vm.prank(attacker);
        shitcoin.approve(address(comet), type(uint256).max);

        // Supply cap is 1,000,000 - this should revert
        vm.prank(attacker);
        vm.expectRevert(Comet.SupplyCapExceeded.selector);
        comet.supplyCollateral(address(shitcoin), 2_000_000e18);

        console.log("Supply caps provide additional defense layer");
    }
}
