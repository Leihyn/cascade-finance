// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

// Lending SDK
import "../src/lending/Comet.sol";
import "../src/lending/CometFactory.sol";
import "../src/lending/models/JumpRateModel.sol";

// DEX SDK
import "../src/dex/core/SwapFactory.sol";
import "../src/dex/periphery/SwapRouter.sol";

// IRS Protocol
import "../src/adapters/CometRateAdapter.sol";
import "../src/pricing/RateOracle.sol";
import "../src/pricing/ChainlinkPriceOracle.sol";
import "../src/core/PositionManager.sol";
import "../src/core/SettlementEngine.sol";
import "../src/risk/MarginEngine.sol";
import "../src/risk/LiquidationEngine.sol";

// Mocks (for testnets)
import "../src/mocks/MockERC20.sol";

/// @title DeployFull
/// @notice Full-stack deployment: Lending SDK + DEX SDK + Cascade IRS Protocol on Flow EVM
/// @dev Deploys the complete Cascade Finance DeFi ecosystem
contract DeployFull is Script {
    /*//////////////////////////////////////////////////////////////
                            DEPLOYED CONTRACTS
    //////////////////////////////////////////////////////////////*/

    // Mocks (testnet only)
    MockERC20 public usdc;
    MockERC20 public wflow;

    // Lending SDK
    CometFactory public cometFactory;
    JumpRateModel public rateModel;
    Comet public comet;
    ChainlinkPriceOracle public priceOracle;

    // DEX SDK
    SwapFactory public swapFactory;
    SwapRouter public swapRouter;

    // IRS Protocol
    CometRateAdapter public rateAdapter;
    RateOracle public rateOracle;
    PositionManager public positionManager;
    SettlementEngine public settlementEngine;
    MarginEngine public marginEngine;
    LiquidationEngine public liquidationEngine;

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    struct FullConfig {
        // Token addresses (or address(0) to deploy mocks)
        address usdcAddress;
        address wflowAddress;
        // Governance
        address governor;
        address feeRecipient;
        // Lending parameters
        uint256 reserveFactor;
        // IRS parameters
        uint256 maxStaleness;
        uint256 settlementInterval;
        // Price oracle (Pyth feeds or address(0) for fallback mode)
        address wflowPriceFeed;
        uint256 wflowFallbackPrice;  // Fallback price if no feed (18 decimals)
    }

    function run() external {
        FullConfig memory config = getConfig();

        vm.startBroadcast();

        // =====================================================
        // Phase 1: Deploy Mocks (if needed)
        // =====================================================
        if (config.usdcAddress == address(0)) {
            usdc = new MockERC20("USD Coin", "USDC", 6);
            console.log("MockUSDC deployed at:", address(usdc));
        } else {
            usdc = MockERC20(config.usdcAddress);
            console.log("Using existing USDC at:", address(usdc));
        }

        if (config.wflowAddress == address(0)) {
            wflow = new MockERC20("Wrapped FLOW", "WFLOW", 18);
            console.log("MockWFLOW deployed at:", address(wflow));
        } else {
            wflow = MockERC20(config.wflowAddress);
            console.log("Using existing WFLOW at:", address(wflow));
        }

        // =====================================================
        // Phase 2: Deploy Lending SDK with Price Oracle
        // =====================================================
        console.log("\n--- Deploying Lending SDK ---");

        cometFactory = new CometFactory(config.governor);
        console.log("CometFactory:", address(cometFactory));

        // JumpRateModel with typical USDC parameters
        // Pre-computed: 4% annual = 1268391679 per second, 109% annual = 34563492063 per second
        rateModel = new JumpRateModel(
            0,                              // 0% base rate
            1268391679,                     // ~4% at 100% util below kink
            34563492063,                    // ~109% jump multiplier
            0.8e18                          // 80% kink
        );
        console.log("JumpRateModel:", address(rateModel));

        // Deploy price oracle for collateral valuation
        priceOracle = new ChainlinkPriceOracle();
        console.log("PriceOracle:", address(priceOracle));

        // Configure price feeds or fallback prices
        if (config.wflowPriceFeed != address(0)) {
            // Use Pyth or other feed
            priceOracle.setPriceFeed(address(wflow), config.wflowPriceFeed, 1 hours);
            console.log("WFLOW price feed configured");
        } else {
            // Use fallback price for testnets
            priceOracle.setFallbackPrice(address(wflow), config.wflowFallbackPrice);
            priceOracle.setFallbackMode(address(wflow), true);
            console.log("WFLOW fallback price set:", config.wflowFallbackPrice);
        }

        comet = new Comet(
            address(usdc),
            6,
            address(rateModel),
            uint64(config.reserveFactor),
            config.governor
        );
        console.log("Comet:", address(comet));

        // CRITICAL: Set the price oracle on Comet
        comet.setPriceOracle(address(priceOracle));
        console.log("Price oracle set on Comet");

        // Add WFLOW as collateral
        comet.addAsset(IComet.AssetConfig({
            asset: address(wflow),
            priceFeed: address(0),           // Legacy field, not used (we use priceOracle)
            borrowCollateralFactor: 0.8e18,  // 80% LTV
            liquidateCollateralFactor: 0.85e18,
            liquidationFactor: 0.9e18,
            supplyCap: 1_000_000e18
        }));
        console.log("WFLOW added as collateral");

        // =====================================================
        // Phase 3: Deploy DEX SDK
        // =====================================================
        console.log("\n--- Deploying DEX SDK ---");

        swapFactory = new SwapFactory(config.governor);
        console.log("SwapFactory:", address(swapFactory));

        swapRouter = new SwapRouter(address(swapFactory), address(wflow));
        console.log("SwapRouter:", address(swapRouter));

        // Create USDC/WFLOW pair
        swapFactory.createPair(address(usdc), address(wflow));
        console.log("USDC/WFLOW pair created");

        // =====================================================
        // Phase 4: Deploy IRS Protocol with Comet Integration
        // =====================================================
        console.log("\n--- Deploying Cascade IRS Protocol ---");

        // CometRateAdapter bridges Lending SDK to IRS
        rateAdapter = new CometRateAdapter(address(comet));
        console.log("CometRateAdapter:", address(rateAdapter));

        // RateOracle with Comet adapter as source
        address[] memory sources = new address[](1);
        sources[0] = address(rateAdapter);
        rateOracle = new RateOracle(sources, 1, config.maxStaleness);
        console.log("RateOracle:", address(rateOracle));

        // PositionManager
        positionManager = new PositionManager(
            address(usdc),
            6,
            config.feeRecipient
        );
        console.log("PositionManager:", address(positionManager));

        // MarginEngine
        marginEngine = new MarginEngine(
            address(positionManager),
            address(rateOracle)
        );
        console.log("MarginEngine:", address(marginEngine));

        // SettlementEngine
        settlementEngine = new SettlementEngine(
            address(positionManager),
            address(rateOracle),
            config.settlementInterval,
            address(usdc),
            config.feeRecipient
        );
        console.log("SettlementEngine:", address(settlementEngine));

        // LiquidationEngine
        liquidationEngine = new LiquidationEngine(
            address(positionManager),
            address(marginEngine),
            address(usdc),
            config.feeRecipient
        );
        console.log("LiquidationEngine:", address(liquidationEngine));

        // Authorize IRS contracts
        positionManager.setAuthorizedContract(address(settlementEngine), true);
        positionManager.setAuthorizedContract(address(liquidationEngine), true);
        console.log("IRS contracts authorized");

        // =====================================================
        // Phase 5: Mint test tokens (testnet only)
        // =====================================================
        if (config.usdcAddress == address(0)) {
            // Mint tokens for testing
            usdc.mint(msg.sender, 10_000_000e6);   // 10M USDC
            usdc.mint(address(comet), 5_000_000e6); // Seed lending pool
            wflow.mint(msg.sender, 10_000e18);      // 10K WFLOW
            console.log("\nTest tokens minted to deployer");
        }

        vm.stopBroadcast();

        // Log full deployment summary
        logDeployment();
    }

    function getConfig() internal view returns (FullConfig memory) {
        uint256 chainId = block.chainid;

        if (chainId == 545) {
            // Flow EVM Testnet
            return getFlowTestnetConfig();
        } else if (chainId == 747) {
            // Flow EVM Mainnet
            return getFlowMainnetConfig();
        } else {
            // Local/Anvil
            return getLocalConfig();
        }
    }

    function getFlowTestnetConfig() internal view returns (FullConfig memory) {
        return FullConfig({
            usdcAddress: address(0), // Deploy mock for testnet
            wflowAddress: address(0), // Deploy mock for testnet
            governor: msg.sender,
            feeRecipient: msg.sender,
            reserveFactor: 0.1e18,
            maxStaleness: 2 hours,
            settlementInterval: 1 hours,
            wflowPriceFeed: address(0), // Use fallback on testnet
            wflowFallbackPrice: 0.5e18  // FLOW ~$0.50 fallback
        });
    }

    function getFlowMainnetConfig() internal view returns (FullConfig memory) {
        return FullConfig({
            usdcAddress: address(0), // TODO: Set bridged USDC address on Flow mainnet
            wflowAddress: address(0), // TODO: Set WFLOW address on Flow mainnet
            governor: msg.sender,
            feeRecipient: msg.sender,
            reserveFactor: 0.1e18,
            maxStaleness: 1 hours,
            settlementInterval: 1 hours,
            wflowPriceFeed: address(0), // TODO: Integrate Pyth oracle
            wflowFallbackPrice: 0.5e18  // FLOW ~$0.50 fallback
        });
    }

    function getLocalConfig() internal view returns (FullConfig memory) {
        return FullConfig({
            usdcAddress: address(0),
            wflowAddress: address(0),
            governor: msg.sender,
            feeRecipient: msg.sender,
            reserveFactor: 0.1e18,
            maxStaleness: 1 hours,
            settlementInterval: 1 hours,
            wflowPriceFeed: address(0),
            wflowFallbackPrice: 0.5e18
        });
    }

    function logDeployment() internal view {
        console.log("\n");
        console.log("============================================================");
        console.log("       CASCADE FINANCE - FULL STACK DEPLOYMENT COMPLETE      ");
        console.log("============================================================");
        console.log("Chain ID:", block.chainid);
        console.log("------------------------------------------------------------");
        console.log("TOKENS");
        console.log("  USDC:", address(usdc));
        console.log("  WFLOW:", address(wflow));
        console.log("------------------------------------------------------------");
        console.log("LENDING SDK");
        console.log("  CometFactory:", address(cometFactory));
        console.log("  JumpRateModel:", address(rateModel));
        console.log("  Comet:", address(comet));
        console.log("------------------------------------------------------------");
        console.log("DEX SDK");
        console.log("  SwapFactory:", address(swapFactory));
        console.log("  SwapRouter:", address(swapRouter));
        console.log("------------------------------------------------------------");
        console.log("CASCADE IRS PROTOCOL");
        console.log("  CometRateAdapter:", address(rateAdapter));
        console.log("  RateOracle:", address(rateOracle));
        console.log("  PositionManager:", address(positionManager));
        console.log("  MarginEngine:", address(marginEngine));
        console.log("  SettlementEngine:", address(settlementEngine));
        console.log("  LiquidationEngine:", address(liquidationEngine));
        console.log("============================================================");
        console.log("\n");
    }
}
