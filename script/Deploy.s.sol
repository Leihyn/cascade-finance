// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/PositionManager.sol";
import "../src/core/SettlementEngine.sol";
import "../src/risk/MarginEngine.sol";
import "../src/risk/LiquidationEngine.sol";
import "../src/pricing/RateOracle.sol";

/// @title Deploy
/// @notice Deployment script for the Cascade IRS Protocol on Flow EVM
contract Deploy is Script {
    // Deployment addresses
    PositionManager public positionManager;
    SettlementEngine public settlementEngine;
    MarginEngine public marginEngine;
    LiquidationEngine public liquidationEngine;
    RateOracle public rateOracle;

    // Configuration
    struct DeployConfig {
        address collateralToken;
        uint8 collateralDecimals;
        address[] rateSources;
        uint256 minRateSources;
        uint256 maxStaleness;
        uint256 settlementInterval;
        address protocolFeeRecipient;
    }

    function run() external {
        // Load configuration based on chain
        DeployConfig memory config = getConfig();

        vm.startBroadcast();

        // 1. Deploy RateOracle
        rateOracle = new RateOracle(
            config.rateSources,
            config.minRateSources,
            config.maxStaleness
        );
        console.log("RateOracle deployed at:", address(rateOracle));

        // 2. Deploy PositionManager (with fee recipient for trading fees)
        positionManager = new PositionManager(
            config.collateralToken,
            config.collateralDecimals,
            config.protocolFeeRecipient
        );
        console.log("PositionManager deployed at:", address(positionManager));

        // 3. Deploy MarginEngine
        marginEngine = new MarginEngine(
            address(positionManager),
            address(rateOracle)
        );
        console.log("MarginEngine deployed at:", address(marginEngine));

        // 4. Deploy SettlementEngine
        settlementEngine = new SettlementEngine(
            address(positionManager),
            address(rateOracle),
            config.settlementInterval,
            config.collateralToken,
            config.protocolFeeRecipient
        );
        console.log("SettlementEngine deployed at:", address(settlementEngine));

        // 5. Deploy LiquidationEngine
        liquidationEngine = new LiquidationEngine(
            address(positionManager),
            address(marginEngine),
            config.collateralToken,
            config.protocolFeeRecipient
        );
        console.log("LiquidationEngine deployed at:", address(liquidationEngine));

        // 6. Authorize contracts
        positionManager.setAuthorizedContract(address(settlementEngine), true);
        positionManager.setAuthorizedContract(address(liquidationEngine), true);
        console.log("Contracts authorized");

        vm.stopBroadcast();

        // Log summary
        logDeployment();
    }

    function getConfig() internal view returns (DeployConfig memory) {
        uint256 chainId = block.chainid;

        if (chainId == 545) {
            // Flow EVM Testnet
            return getFlowTestnetConfig();
        } else if (chainId == 747) {
            // Flow EVM Mainnet
            return getFlowMainnetConfig();
        } else {
            // Local/Anvil - use mock config
            return getLocalConfig();
        }
    }

    function getFlowTestnetConfig() internal view returns (DeployConfig memory) {
        address[] memory sources = new address[](1);
        sources[0] = address(0); // Mock source for testnet

        return DeployConfig({
            collateralToken: address(0), // Deploy mock USDC
            collateralDecimals: 6,
            rateSources: sources,
            minRateSources: 1,
            maxStaleness: 2 hours,
            settlementInterval: 1 hours,
            protocolFeeRecipient: msg.sender
        });
    }

    function getFlowMainnetConfig() internal view returns (DeployConfig memory) {
        address[] memory sources = new address[](1);
        sources[0] = address(0); // TODO: Set after rate adapter deployment

        return DeployConfig({
            collateralToken: address(0), // TODO: Set bridged USDC on Flow
            collateralDecimals: 6,
            rateSources: sources,
            minRateSources: 1,
            maxStaleness: 1 hours,
            settlementInterval: 1 hours,
            protocolFeeRecipient: msg.sender
        });
    }

    function getLocalConfig() internal view returns (DeployConfig memory) {
        address[] memory sources = new address[](1);
        sources[0] = address(0); // Will deploy mock

        return DeployConfig({
            collateralToken: address(0), // Will deploy mock
            collateralDecimals: 6,
            rateSources: sources,
            minRateSources: 1,
            maxStaleness: 1 hours,
            settlementInterval: 1 hours,
            protocolFeeRecipient: msg.sender
        });
    }

    function logDeployment() internal view {
        console.log("\n========== CASCADE IRS DEPLOYMENT ==========");
        console.log("Chain ID:", block.chainid);
        console.log("RateOracle:", address(rateOracle));
        console.log("PositionManager:", address(positionManager));
        console.log("MarginEngine:", address(marginEngine));
        console.log("SettlementEngine:", address(settlementEngine));
        console.log("LiquidationEngine:", address(liquidationEngine));
        console.log("=============================================\n");
    }
}
