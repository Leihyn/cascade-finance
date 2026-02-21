// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/PositionManager.sol";
import "../src/core/SettlementEngine.sol";
import "../src/risk/MarginEngine.sol";
import "../src/risk/LiquidationEngine.sol";
import "../src/pricing/RateOracle.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockRateSource.sol";

/// @title DeployLocal
/// @notice Local deployment with mocks for testing
contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy mocks
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("MockUSDC deployed at:", address(usdc));

        MockRateSource rateSource = new MockRateSource(0.05e18, 0.07e18);
        console.log("MockRateSource deployed at:", address(rateSource));

        // Deploy oracle
        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        RateOracle oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();
        console.log("RateOracle deployed at:", address(oracle));

        // Deploy core contracts
        // PositionManager now takes fee recipient for trading fees
        PositionManager pm = new PositionManager(address(usdc), 6, msg.sender);
        console.log("PositionManager deployed at:", address(pm));

        MarginEngine marginEngine = new MarginEngine(address(pm), address(oracle));
        console.log("MarginEngine deployed at:", address(marginEngine));

        // SettlementEngine now takes collateral token and fee recipient for settlement/close fees
        SettlementEngine settlement = new SettlementEngine(
            address(pm),
            address(oracle),
            1 hours,
            address(usdc),
            msg.sender
        );
        console.log("SettlementEngine deployed at:", address(settlement));

        LiquidationEngine liquidation = new LiquidationEngine(
            address(pm),
            address(marginEngine),
            address(usdc),
            msg.sender
        );
        console.log("LiquidationEngine deployed at:", address(liquidation));

        // Authorize
        pm.setAuthorizedContract(address(settlement), true);
        pm.setAuthorizedContract(address(liquidation), true);

        // Mint test tokens
        usdc.mint(msg.sender, 1_000_000e6);
        usdc.mint(address(pm), 1_000_000e6);
        usdc.mint(address(liquidation), 100_000e6);

        vm.stopBroadcast();

        console.log("\n=== LOCAL DEPLOYMENT COMPLETE ===");
        console.log("Test USDC minted to deployer: 1,000,000");
        console.log("\n=== PROTOCOL FEES ===");
        console.log("Trading Fee: 0.05% of notional");
        console.log("Settlement Fee: 1% of positive PnL");
        console.log("Close Fee: 0.02% of notional");
        console.log("Fee Recipient:", msg.sender);
    }
}
