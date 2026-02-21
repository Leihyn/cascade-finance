// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/lending/Comet.sol";
import "../src/lending/CometFactory.sol";
import "../src/lending/models/JumpRateModel.sol";
import "../src/pricing/ChainlinkPriceOracle.sol";
import "../src/mocks/MockERC20.sol";

/// @title DeployLending
/// @notice Deployment script for the Cascade Lending SDK on Flow EVM
contract DeployLending is Script {
    // Deployed contracts
    CometFactory public cometFactory;
    JumpRateModel public rateModel;
    Comet public comet;
    ChainlinkPriceOracle public priceOracle;

    struct LendingConfig {
        address baseToken;
        uint8 baseTokenDecimals;
        address governor;
        // Rate model parameters
        uint256 baseRatePerSecond;
        uint256 multiplierPerSecond;
        uint256 jumpMultiplierPerSecond;
        uint256 kink;
        // Comet parameters
        uint256 reserveFactor;
        // Price oracle (Pyth feeds or fallback mode)
        address wflowAddress;
        address wflowPriceFeed;
        uint256 wflowFallbackPrice;
    }

    function run() external {
        LendingConfig memory config = getConfig();

        vm.startBroadcast();

        // 1. Deploy CometFactory
        cometFactory = new CometFactory(config.governor);
        console.log("CometFactory deployed at:", address(cometFactory));

        // 2. Deploy JumpRateModel
        rateModel = new JumpRateModel(
            config.baseRatePerSecond,
            config.multiplierPerSecond,
            config.jumpMultiplierPerSecond,
            config.kink
        );
        console.log("JumpRateModel deployed at:", address(rateModel));

        // 3. Deploy Comet (USDC market)
        comet = new Comet(
            config.baseToken,
            config.baseTokenDecimals,
            address(rateModel),
            uint64(config.reserveFactor),
            config.governor
        );
        console.log("Comet deployed at:", address(comet));

        // 4. Deploy PriceOracle for collateral valuation
        priceOracle = new ChainlinkPriceOracle();
        console.log("PriceOracle deployed at:", address(priceOracle));

        // 5. Configure price feeds or fallback prices
        if (config.wflowAddress != address(0)) {
            if (config.wflowPriceFeed != address(0)) {
                priceOracle.setPriceFeed(config.wflowAddress, config.wflowPriceFeed, 1 hours);
                console.log("WFLOW price feed configured");
            } else {
                priceOracle.setFallbackPrice(config.wflowAddress, config.wflowFallbackPrice);
                priceOracle.setFallbackMode(config.wflowAddress, true);
                console.log("WFLOW fallback price set:", config.wflowFallbackPrice);
            }
        }

        // 6. Set price oracle on Comet
        comet.setPriceOracle(address(priceOracle));
        console.log("Price oracle set on Comet");

        vm.stopBroadcast();

        logDeployment();
    }

    function getConfig() internal view returns (LendingConfig memory) {
        uint256 chainId = block.chainid;

        if (chainId == 545) {
            return getFlowTestnetConfig();
        } else if (chainId == 747) {
            return getFlowMainnetConfig();
        } else {
            return getLocalConfig();
        }
    }

    // Pre-computed rate constants (per-second rates)
    uint256 constant MULTIPLIER_PER_SECOND = 1268391679;       // ~4% annual
    uint256 constant JUMP_MULTIPLIER_PER_SECOND = 34563492063;  // ~109% annual

    function getFlowTestnetConfig() internal view returns (LendingConfig memory) {
        return LendingConfig({
            baseToken: address(0),          // Deploy mock USDC
            baseTokenDecimals: 6,
            governor: msg.sender,
            baseRatePerSecond: 0,
            multiplierPerSecond: MULTIPLIER_PER_SECOND,
            jumpMultiplierPerSecond: JUMP_MULTIPLIER_PER_SECOND,
            kink: 0.8e18,
            reserveFactor: 0.1e18,
            wflowAddress: address(0),
            wflowPriceFeed: address(0),
            wflowFallbackPrice: 0.5e18
        });
    }

    function getFlowMainnetConfig() internal view returns (LendingConfig memory) {
        return LendingConfig({
            baseToken: address(0),          // TODO: Set bridged USDC on Flow
            baseTokenDecimals: 6,
            governor: msg.sender,
            baseRatePerSecond: 0,
            multiplierPerSecond: MULTIPLIER_PER_SECOND,
            jumpMultiplierPerSecond: JUMP_MULTIPLIER_PER_SECOND,
            kink: 0.8e18,
            reserveFactor: 0.1e18,
            wflowAddress: address(0),       // TODO: Set WFLOW address
            wflowPriceFeed: address(0),     // TODO: Integrate Pyth
            wflowFallbackPrice: 0.5e18
        });
    }

    function getLocalConfig() internal pure returns (LendingConfig memory) {
        return LendingConfig({
            baseToken: address(0),
            baseTokenDecimals: 6,
            governor: address(0),
            baseRatePerSecond: 0,
            multiplierPerSecond: MULTIPLIER_PER_SECOND,
            jumpMultiplierPerSecond: JUMP_MULTIPLIER_PER_SECOND,
            kink: 0.8e18,
            reserveFactor: 0.1e18,
            wflowAddress: address(0),
            wflowPriceFeed: address(0),
            wflowFallbackPrice: 0.5e18
        });
    }

    function logDeployment() internal view {
        console.log("\n========== CASCADE LENDING SDK DEPLOYMENT ==========");
        console.log("Chain ID:", block.chainid);
        console.log("CometFactory:", address(cometFactory));
        console.log("JumpRateModel:", address(rateModel));
        console.log("Comet (USDC):", address(comet));
        console.log("PriceOracle:", address(priceOracle));
        console.log("====================================================\n");
    }
}
