// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/lending/models/JumpRateModel.sol";

contract JumpRateModelTest is Test {
    JumpRateModel public rateModel;

    // Standard parameters (similar to Compound USDC)
    uint256 constant BASE_RATE_PER_YEAR = 0; // 0%
    uint256 constant MULTIPLIER_PER_YEAR = 0.04e18; // 4%
    uint256 constant JUMP_MULTIPLIER_PER_YEAR = 1.09e18; // 109%
    uint256 constant KINK = 0.8e18; // 80% utilization

    function setUp() public {
        rateModel = new JumpRateModel(
            BASE_RATE_PER_YEAR,
            MULTIPLIER_PER_YEAR,
            JUMP_MULTIPLIER_PER_YEAR,
            KINK
        );
    }

    /*//////////////////////////////////////////////////////////////
                          UTILIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_utilizationRate_zeroBorrows() public view {
        uint256 util = rateModel.utilizationRate(1000e6, 0, 0);
        assertEq(util, 0, "Utilization should be 0 with no borrows");
    }

    function test_utilizationRate_allBorrowed() public view {
        // 100% borrowed
        uint256 util = rateModel.utilizationRate(0, 1000e6, 0);
        assertEq(util, 1e18, "Utilization should be 100% when all borrowed");
    }

    function test_utilizationRate_halfBorrowed() public view {
        // 50% utilization: 500 borrowed out of 1000 total
        uint256 util = rateModel.utilizationRate(500e6, 500e6, 0);
        assertEq(util, 0.5e18, "Utilization should be 50%");
    }

    function test_utilizationRate_withReserves() public view {
        // Cash = 200, Borrows = 800, Reserves = 100
        // Total = 1000, Available = 900
        // Util = 800 / 900 = 88.89%
        uint256 util = rateModel.utilizationRate(200e6, 800e6, 100e6);
        assertApproxEqRel(util, 0.8889e18, 0.001e18, "Utilization should be ~88.89%");
    }

    /*//////////////////////////////////////////////////////////////
                          BORROW RATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_borrowRate_zeroUtilization() public view {
        uint256 rate = rateModel.getBorrowRate(1000e6, 0, 0);
        assertEq(rate, 0, "Borrow rate should be 0 at 0% utilization");
    }

    function test_borrowRate_atKink() public view {
        // At 80% utilization (kink)
        uint256 rate = rateModel.getBorrowRate(200e6, 800e6, 0);

        // Expected: baseRate + kink * multiplier = 0 + 0.8 * 0.04 = 3.2% per year
        uint256 expectedRatePerYear = 0.032e18;
        uint256 expectedRatePerSecond = expectedRatePerYear / 365 days;

        assertApproxEqRel(rate, expectedRatePerSecond, 0.001e18, "Rate should be ~3.2% at kink");
    }

    function test_borrowRate_aboveKink() public view {
        // At 90% utilization (above kink)
        uint256 rate = rateModel.getBorrowRate(100e6, 900e6, 0);

        // Expected:
        // Normal rate at kink: 0 + 0.8 * 0.04 = 3.2%
        // Excess: (0.9 - 0.8) * 1.09 = 10.9%
        // Total: 3.2% + 10.9% = 14.1% per year
        uint256 expectedRatePerYear = 0.141e18;
        uint256 expectedRatePerSecond = expectedRatePerYear / 365 days;

        assertApproxEqRel(rate, expectedRatePerSecond, 0.01e18, "Rate should be ~14.1% above kink");
    }

    function test_borrowRate_fullUtilization() public view {
        // At 100% utilization
        uint256 rate = rateModel.getBorrowRate(0, 1000e6, 0);

        // Expected:
        // Normal rate at kink: 0 + 0.8 * 0.04 = 3.2%
        // Excess: (1.0 - 0.8) * 1.09 = 21.8%
        // Total: 3.2% + 21.8% = 25% per year
        uint256 expectedRatePerYear = 0.25e18;
        uint256 expectedRatePerSecond = expectedRatePerYear / 365 days;

        assertApproxEqRel(rate, expectedRatePerSecond, 0.01e18, "Rate should be ~25% at full utilization");
    }

    /*//////////////////////////////////////////////////////////////
                          SUPPLY RATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supplyRate_zeroUtilization() public view {
        uint256 rate = rateModel.getSupplyRate(1000e6, 0, 0, 0.1e18);
        assertEq(rate, 0, "Supply rate should be 0 at 0% utilization");
    }

    function test_supplyRate_withReserveFactor() public view {
        // 50% utilization, 10% reserve factor
        uint256 rate = rateModel.getSupplyRate(500e6, 500e6, 0, 0.1e18);

        // Borrow rate at 50% util: 0 + 0.5 * 0.04 = 2% per year
        // Supply rate: borrowRate * util * (1 - reserveFactor) = 0.02 * 0.5 * 0.9 = 0.9% per year
        uint256 expectedRatePerYear = 0.009e18;
        uint256 expectedRatePerSecond = expectedRatePerYear / 365 days;

        assertApproxEqRel(rate, expectedRatePerSecond, 0.01e18, "Supply rate should be ~0.9%");
    }

    /*//////////////////////////////////////////////////////////////
                          ANNUALIZED RATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_borrowRatePerYear() public view {
        uint256 ratePerYear = rateModel.getBorrowRatePerYear(200e6, 800e6, 0);
        assertApproxEqRel(ratePerYear, 0.032e18, 0.001e18, "Annual borrow rate should be ~3.2%");
    }

    function test_supplyRatePerYear() public view {
        uint256 ratePerYear = rateModel.getSupplyRatePerYear(500e6, 500e6, 0, 0.1e18);
        assertApproxEqRel(ratePerYear, 0.009e18, 0.01e18, "Annual supply rate should be ~0.9%");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_utilizationRateBounded(
        uint128 cash,
        uint128 borrows
    ) public view {
        // Use uint128 to ensure no overflow when added
        // Reserves always 0 for simplicity
        uint256 reserves = 0;

        uint256 util = rateModel.utilizationRate(cash, borrows, reserves);
        assertLe(util, 1e18, "Utilization should never exceed 100%");
    }

    function testFuzz_borrowRateIncreasesWithUtilization(
        uint256 util1,
        uint256 util2
    ) public view {
        util1 = bound(util1, 0, 0.99e18);
        util2 = bound(util2, util1, 1e18);

        // Create cash/borrow amounts that give us these utilizations
        uint256 total = 1e18;
        uint256 borrows1 = (total * util1) / 1e18;
        uint256 cash1 = total - borrows1;

        uint256 borrows2 = (total * util2) / 1e18;
        uint256 cash2 = total - borrows2;

        uint256 rate1 = rateModel.getBorrowRate(cash1, borrows1, 0);
        uint256 rate2 = rateModel.getBorrowRate(cash2, borrows2, 0);

        assertGe(rate2, rate1, "Higher utilization should have higher or equal borrow rate");
    }
}
