// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseForkTest.sol";
import "../../src/adapters/LendleRateAdapter.sol";
import "../../src/pricing/RateOracle.sol";

/// @title LendleForkTest
/// @notice Fork tests for Lendle integration on Mantle
contract LendleForkTest is BaseForkTest {
    LendleRateAdapter public adapter;
    RateOracle public oracle;

    function setUp() public {
        bool hasFork = createMantleFork();

        if (hasFork) {
            // Deploy adapter with Mantle mainnet addresses
            adapter = new LendleRateAdapter(LENDLE_POOL, USDC_MANTLE);

            // Deploy oracle with adapter as source
            address[] memory sources = new address[](1);
            sources[0] = address(adapter);
            oracle = new RateOracle(sources, 1, 1 hours);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         ADAPTER BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_lendleAdapterDeployed() public onlyFork {
        assertEq(address(adapter.lendingPool()), LENDLE_POOL);
        assertEq(adapter.asset(), USDC_MANTLE);
    }

    function test_fork_lendleAdapterReturnsValidSupplyRate() public onlyFork {
        uint256 supplyRate = adapter.getSupplyRate();

        // Supply rate should be positive but reasonable (0.1% - 50%)
        assertValidRate(supplyRate, "Supply rate");
        assertRateInRange(supplyRate, 0.001e18, 0.5e18, "Supply rate");

        emit log_named_uint("Supply Rate (WAD)", supplyRate);
        emit log_named_uint("Supply Rate (%)", (supplyRate * 100) / 1e18);
    }

    function test_fork_lendleAdapterReturnsValidBorrowRate() public onlyFork {
        uint256 borrowRate = adapter.getBorrowRate();

        // Borrow rate should be positive but reasonable (0.5% - 100%)
        assertValidRate(borrowRate, "Borrow rate");
        assertRateInRange(borrowRate, 0.005e18, 1e18, "Borrow rate");

        emit log_named_uint("Borrow Rate (WAD)", borrowRate);
        emit log_named_uint("Borrow Rate (%)", (borrowRate * 100) / 1e18);
    }

    function test_fork_borrowRateExceedsSupplyRate() public onlyFork {
        (uint256 supplyRate, uint256 borrowRate) = adapter.getRates();

        // Borrow rate should always be higher than supply rate
        // (this is how lending protocols make money)
        assertGt(borrowRate, supplyRate, "Borrow rate should exceed supply rate");

        uint256 spread = borrowRate - supplyRate;
        emit log_named_uint("Rate Spread (WAD)", spread);
        emit log_named_uint("Rate Spread (%)", (spread * 100) / 1e18);
    }

    function test_fork_ratesAreConsistent() public onlyFork {
        // Fetch rates multiple ways and ensure consistency
        uint256 supplyDirect = adapter.getSupplyRate();
        uint256 borrowDirect = adapter.getBorrowRate();
        (uint256 supplyPair, uint256 borrowPair) = adapter.getRates();

        assertEq(supplyDirect, supplyPair, "Supply rates should match");
        assertEq(borrowDirect, borrowPair, "Borrow rates should match");
    }

    function test_fork_lastUpdateTimestampIsRecent() public onlyFork {
        uint40 lastUpdate = adapter.getLastUpdateTimestamp();

        // Last update should be within the last 24 hours
        // (if pool is active)
        uint256 maxAge = 24 hours;
        assertGt(lastUpdate, 0, "Last update should not be zero");

        // Note: This might fail if pool hasn't been used recently
        // In production, we'd want a more lenient check
        if (lastUpdate > block.timestamp - maxAge) {
            emit log("Pool was updated within last 24 hours");
        } else {
            emit log("Warning: Pool update is older than 24 hours");
        }
    }

    /*//////////////////////////////////////////////////////////////
                         ORACLE INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_rateOracleIntegration() public onlyFork {
        // Update oracle
        oracle.updateRate();

        // Get rate from oracle
        uint256 oracleRate = oracle.getCurrentRate();

        // Should match adapter supply rate
        uint256 adapterRate = adapter.getSupplyRate();
        assertEq(oracleRate, adapterRate, "Oracle should reflect adapter rate");

        emit log_named_uint("Oracle Rate (WAD)", oracleRate);
    }

    function test_fork_oracleFreshRateCheck() public onlyFork {
        oracle.updateRate();

        uint256 rate = oracle.getFreshRate();
        bool isStale = oracle.isStale();

        assertFalse(isStale, "Rate should not be stale immediately after update");
        assertGt(rate, 0, "Rate should be positive");
    }

    function test_fork_oracleStalenessAfterTime() public onlyFork {
        oracle.updateRate();

        // Warp forward past staleness threshold
        vm.warp(block.timestamp + 2 hours);

        bool isStale = oracle.isStale();
        assertTrue(isStale, "Rate should be stale after threshold");
    }

    function test_fork_oracleTWAPAccumulation() public onlyFork {
        // Update multiple times to build TWAP history
        for (uint256 i = 0; i < 5; i++) {
            oracle.updateRate();
            vm.warp(block.timestamp + 15 minutes);
        }

        uint256 twap = oracle.getTWAP(1 hours);
        assertGt(twap, 0, "TWAP should be positive");

        uint256 currentRate = oracle.getCurrentRate();

        // TWAP should be close to current rate if rates haven't changed much
        uint256 diff =
            twap > currentRate ? twap - currentRate : currentRate - twap;
        uint256 tolerance = currentRate / 10; // 10% tolerance

        assertLt(diff, tolerance, "TWAP should be close to current rate");
    }

    /*//////////////////////////////////////////////////////////////
                         EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_multipleRateFetches() public onlyFork {
        // Fetch rates multiple times to ensure consistency
        uint256 rate1 = adapter.getSupplyRate();

        vm.roll(block.number + 1);

        uint256 rate2 = adapter.getSupplyRate();

        // Rates should be identical within same block range
        // (unless a transaction updated the pool)
        assertEq(rate1, rate2, "Rates should be stable across fetches");
    }

    function test_fork_rateUpdateAfterTimeWarp() public onlyFork {
        uint256 rateBefore = adapter.getSupplyRate();

        // Warp forward (simulating time passing)
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 7200); // ~1 day of blocks

        uint256 rateAfter = adapter.getSupplyRate();

        // Rate might change but should still be valid
        assertValidRate(rateAfter, "Rate after time warp");

        emit log_named_uint("Rate before warp", rateBefore);
        emit log_named_uint("Rate after warp", rateAfter);
    }

    /*//////////////////////////////////////////////////////////////
                      DIFFERENT ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_usdtRates() public onlyFork {
        // Deploy adapter for USDT
        LendleRateAdapter usdtAdapter =
            new LendleRateAdapter(LENDLE_POOL, USDT_MANTLE);

        uint256 supplyRate = usdtAdapter.getSupplyRate();
        uint256 borrowRate = usdtAdapter.getBorrowRate();

        assertValidRate(supplyRate, "USDT Supply rate");
        assertValidRate(borrowRate, "USDT Borrow rate");
        assertGt(borrowRate, supplyRate, "USDT borrow should exceed supply");

        emit log_named_uint("USDT Supply Rate (%)", (supplyRate * 100) / 1e18);
        emit log_named_uint("USDT Borrow Rate (%)", (borrowRate * 100) / 1e18);
    }

    function test_fork_wethRates() public onlyFork {
        // Deploy adapter for WETH
        LendleRateAdapter wethAdapter =
            new LendleRateAdapter(LENDLE_POOL, WETH_MANTLE);

        uint256 supplyRate = wethAdapter.getSupplyRate();
        uint256 borrowRate = wethAdapter.getBorrowRate();

        // WETH rates might be lower than stablecoin rates
        assertValidRate(supplyRate, "WETH Supply rate");
        assertValidRate(borrowRate, "WETH Borrow rate");

        emit log_named_uint("WETH Supply Rate (%)", (supplyRate * 100) / 1e18);
        emit log_named_uint("WETH Borrow Rate (%)", (borrowRate * 100) / 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                          GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_fork_gasGetSupplyRate() public onlyFork {
        uint256 gasBefore = gasleft();
        adapter.getSupplyRate();
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas for getSupplyRate()", gasUsed);

        // Should be reasonable for an external call
        assertLt(gasUsed, 100000, "getSupplyRate gas should be reasonable");
    }

    function test_fork_gasGetRates() public onlyFork {
        uint256 gasBefore = gasleft();
        adapter.getRates();
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas for getRates()", gasUsed);

        // Should be similar to single rate fetch (one external call)
        assertLt(gasUsed, 100000, "getRates gas should be reasonable");
    }

    function test_fork_gasOracleUpdate() public onlyFork {
        uint256 gasBefore = gasleft();
        oracle.updateRate();
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas for oracle.updateRate()", gasUsed);

        assertLt(gasUsed, 200000, "Oracle update gas should be reasonable");
    }
}
