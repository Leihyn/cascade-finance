// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/dex/core/SwapFactory.sol";
import "../src/dex/periphery/SwapRouter.sol";

/// @title DeployDex
/// @notice Deployment script for the Cascade DEX SDK on Flow EVM
contract DeployDex is Script {
    // Deployed contracts
    SwapFactory public swapFactory;
    SwapRouter public swapRouter;

    struct DexConfig {
        address governor;
        address wflow;
    }

    function run() external {
        DexConfig memory config = getConfig();

        vm.startBroadcast();

        // 1. Deploy SwapFactory
        swapFactory = new SwapFactory(config.governor);
        console.log("SwapFactory deployed at:", address(swapFactory));

        // 2. Deploy SwapRouter
        swapRouter = new SwapRouter(address(swapFactory), config.wflow);
        console.log("SwapRouter deployed at:", address(swapRouter));

        vm.stopBroadcast();

        logDeployment();
    }

    function getConfig() internal view returns (DexConfig memory) {
        uint256 chainId = block.chainid;

        if (chainId == 545) {
            return getFlowTestnetConfig();
        } else if (chainId == 747) {
            return getFlowMainnetConfig();
        } else {
            return getLocalConfig();
        }
    }

    function getFlowTestnetConfig() internal view returns (DexConfig memory) {
        return DexConfig({
            governor: msg.sender,
            wflow: address(0) // Deploy mock WFLOW
        });
    }

    function getFlowMainnetConfig() internal view returns (DexConfig memory) {
        return DexConfig({
            governor: msg.sender,
            wflow: address(0) // TODO: Set WFLOW address on Flow mainnet
        });
    }

    function getLocalConfig() internal view returns (DexConfig memory) {
        return DexConfig({
            governor: msg.sender,
            wflow: address(0) // Will be set by DeployFull
        });
    }

    function logDeployment() internal view {
        console.log("\n========== CASCADE DEX SDK DEPLOYMENT ==========");
        console.log("Chain ID:", block.chainid);
        console.log("SwapFactory:", address(swapFactory));
        console.log("SwapRouter:", address(swapRouter));
        console.log("================================================\n");
    }
}
