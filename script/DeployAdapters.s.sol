// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/adapters/AaveV3RateAdapter.sol";
import "../src/adapters/CompoundV3RateAdapter.sol";

/// @title DeployAdapters
/// @notice Deploy rate adapters for different networks
contract DeployAdapters is Script {
    // Aave V3 Pool addresses
    address constant AAVE_V3_POOL_BASE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_V3_POOL_ARBITRUM = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant AAVE_V3_POOL_ETHEREUM = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // Compound V3 Comet addresses (USDC markets)
    address constant COMPOUND_V3_USDC_BASE = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
    address constant COMPOUND_V3_USDC_ARBITRUM = 0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA;
    address constant COMPOUND_V3_USDC_ETHEREUM = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;

    // USDC addresses
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant USDC_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() external {
        uint256 chainId = block.chainid;

        vm.startBroadcast();

        if (chainId == 8453) {
            deployBase();
        } else if (chainId == 42161) {
            deployArbitrum();
        } else if (chainId == 1) {
            deployEthereum();
        } else {
            console.log("Unsupported chain for adapter deployment");
        }

        vm.stopBroadcast();
    }

    function deployBase() internal {
        console.log("Deploying adapters on Base...");

        AaveV3RateAdapter aaveAdapter = new AaveV3RateAdapter(
            AAVE_V3_POOL_BASE,
            USDC_BASE
        );
        console.log("Aave V3 Adapter:", address(aaveAdapter));

        CompoundV3RateAdapter compoundAdapter = new CompoundV3RateAdapter(
            COMPOUND_V3_USDC_BASE
        );
        console.log("Compound V3 Adapter:", address(compoundAdapter));

        // Log current rates
        console.log("Aave Supply Rate:", aaveAdapter.getSupplyRate());
        console.log("Compound Supply Rate:", compoundAdapter.getSupplyRate());
    }

    function deployArbitrum() internal {
        console.log("Deploying adapters on Arbitrum...");

        AaveV3RateAdapter aaveAdapter = new AaveV3RateAdapter(
            AAVE_V3_POOL_ARBITRUM,
            USDC_ARBITRUM
        );
        console.log("Aave V3 Adapter:", address(aaveAdapter));

        CompoundV3RateAdapter compoundAdapter = new CompoundV3RateAdapter(
            COMPOUND_V3_USDC_ARBITRUM
        );
        console.log("Compound V3 Adapter:", address(compoundAdapter));
    }

    function deployEthereum() internal {
        console.log("Deploying adapters on Ethereum...");

        AaveV3RateAdapter aaveAdapter = new AaveV3RateAdapter(
            AAVE_V3_POOL_ETHEREUM,
            USDC_ETHEREUM
        );
        console.log("Aave V3 Adapter:", address(aaveAdapter));

        CompoundV3RateAdapter compoundAdapter = new CompoundV3RateAdapter(
            COMPOUND_V3_USDC_ETHEREUM
        );
        console.log("Compound V3 Adapter:", address(compoundAdapter));
    }
}
