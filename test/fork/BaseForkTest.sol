// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// @title BaseForkTest
/// @notice Base contract for fork tests with common utilities
abstract contract BaseForkTest is Test {
    /// @notice Mantle chain ID
    uint256 public constant MANTLE_CHAIN_ID = 5000;

    /// @notice Base Sepolia chain ID
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;

    /// @notice Fork identifier
    uint256 public forkId;

    /// @notice Whether we're on a fork (renamed to avoid conflict with forge-std)
    bool public hasForkActive;

    /// @notice Lendle LendingPool on Mantle Mainnet
    address public constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    /// @notice USDC on Mantle
    address public constant USDC_MANTLE = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;

    /// @notice USDT on Mantle
    address public constant USDT_MANTLE = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;

    /// @notice WETH on Mantle
    address public constant WETH_MANTLE = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;

    /// @notice Common rate bounds for validation
    uint256 public constant MIN_VALID_RATE = 0.001e18; // 0.1%
    uint256 public constant MAX_VALID_RATE = 1e18; // 100%

    /// @notice Setup fork if RPC URL is available
    modifier onlyFork() {
        if (!hasForkActive) {
            vm.skip(true);
        }
        _;
    }

    /// @notice Create a fork from environment variable
    /// @param envVar Environment variable name for RPC URL
    function createFork(string memory envVar) internal returns (bool) {
        try vm.envString(envVar) returns (string memory rpcUrl) {
            if (bytes(rpcUrl).length > 0) {
                forkId = vm.createFork(rpcUrl);
                vm.selectFork(forkId);
                hasForkActive = true;
                return true;
            }
        } catch {
            // RPC URL not set, skip fork tests
        }
        return false;
    }

    /// @notice Create Mantle mainnet fork
    function createMantleFork() internal returns (bool) {
        return createFork("MANTLE_RPC_URL");
    }

    /// @notice Create Base Sepolia fork
    function createBaseSepoliaFork() internal returns (bool) {
        return createFork("BASE_SEPOLIA_RPC_URL");
    }

    /// @notice Validate that a rate is within reasonable bounds
    function assertValidRate(uint256 rate, string memory label) internal pure {
        assertTrue(rate > 0, string.concat(label, ": rate should be > 0"));
        assertTrue(rate < MAX_VALID_RATE, string.concat(label, ": rate should be < 100%"));
    }

    /// @notice Assert rate is within expected range
    function assertRateInRange(
        uint256 rate,
        uint256 minRate,
        uint256 maxRate,
        string memory label
    ) internal pure {
        assertTrue(rate >= minRate, string.concat(label, ": rate below minimum"));
        assertTrue(rate <= maxRate, string.concat(label, ": rate above maximum"));
    }

    /// @notice Log rate in human-readable format
    function logRate(string memory label, uint256 rate) internal pure {
        // Convert WAD to percentage with 4 decimals
        uint256 percentage = (rate * 10000) / 1e18;
        uint256 whole = percentage / 100;
        uint256 decimal = percentage % 100;

        // Note: In actual test output, we'd use console.log
        // but for pure function we just validate
    }
}
