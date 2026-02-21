// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/adapters/MockRateSource.sol";
import "../src/pricing/RateOracle.sol";

/// @notice Deploy MockRateSource and add it to RateOracle
/// @dev Only for testnet - provides fallback rates when lending pool has no activity
contract AddMockRateSource is Script {
    function run() external {
        // Use the private key passed via --private-key flag
        address deployer = msg.sender;

        // Base Sepolia addresses
        address rateOracleAddr = 0x8D1d3d7c373E84509DC86d1000cBDDE92123b23b;

        vm.startBroadcast();

        // Deploy MockRateSource with 5% supply rate, 8% borrow rate
        MockRateSource mockSource = new MockRateSource();
        console.log("MockRateSource deployed at:", address(mockSource));

        // Add to RateOracle
        RateOracle oracle = RateOracle(rateOracleAddr);
        oracle.addSource(address(mockSource));
        console.log("MockRateSource added to RateOracle");

        // Verify it works
        uint256 rate = oracle.getCurrentRate();
        console.log("Current rate from oracle:", rate);
        console.log("Rate as percentage:", rate * 100 / 1e18, "%");

        vm.stopBroadcast();
    }
}
