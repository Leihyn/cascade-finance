// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/governance/IRSGovernor.sol";
import "../src/pricing/ChainlinkPriceOracle.sol";
import "../src/amm/IRSPool.sol";
import "../src/amm/IRSPoolFactory.sol";

/// @title DeployGovernanceAndAMM
/// @notice Deploys governance and AMM contracts for the IRS protocol
contract DeployGovernanceAndAMM is Script {
    // Deployment addresses
    address public governor;
    address public priceOracle;
    address public poolFactory;
    address public pool30Day;
    address public pool90Day;

    function run() external {
        // Load environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get USDC address (already deployed)
        address usdc = vm.envOr("USDC_ADDRESS", address(0));
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);

        console.log("Deployer:", deployer);
        console.log("USDC:", usdc);
        console.log("Fee Recipient:", feeRecipient);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Governance
        governor = address(new IRSGovernor(
            1000e18,        // proposalThreshold: 1000 tokens
            3 days,         // votingPeriod
            1 days,         // votingDelay
            2 days,         // timelockDelay
            400             // quorumBps: 4%
        ));
        console.log("IRSGovernor deployed at:", governor);

        // 2. Deploy Chainlink Price Oracle
        priceOracle = address(new ChainlinkPriceOracle());
        console.log("ChainlinkPriceOracle deployed at:", priceOracle);

        // 3. Deploy IRS Pool Factory
        poolFactory = address(new IRSPoolFactory(feeRecipient));
        console.log("IRSPoolFactory deployed at:", poolFactory);

        // 4. Deploy IRS Pools (if USDC is set)
        if (usdc != address(0)) {
            // 30-day pool at 5% initial rate
            IRSPoolFactory factory = IRSPoolFactory(poolFactory);

            pool30Day = factory.createPool(
                usdc,
                6,              // USDC decimals
                30,             // 30 day maturity
                "Comet USDC",   // Rate source
                0.05e18         // 5% initial rate
            );
            console.log("30-Day IRS Pool deployed at:", pool30Day);

            // 90-day pool at 5.5% initial rate
            pool90Day = factory.createPool(
                usdc,
                6,
                90,
                "Comet USDC",
                0.055e18        // 5.5% initial rate
            );
            console.log("90-Day IRS Pool deployed at:", pool90Day);
        }

        vm.stopBroadcast();

        // Log summary
        console.log("\n=== Deployment Summary ===");
        console.log("IRSGovernor:", governor);
        console.log("ChainlinkPriceOracle:", priceOracle);
        console.log("IRSPoolFactory:", poolFactory);
        if (usdc != address(0)) {
            console.log("30-Day Pool:", pool30Day);
            console.log("90-Day Pool:", pool90Day);
        }
    }
}
