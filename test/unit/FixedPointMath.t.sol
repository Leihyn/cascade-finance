// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/libraries/FixedPointMath.sol";

contract FixedPointMathTest is Test {
    using FixedPointMath for uint256;

    uint256 constant WAD = 1e18;
    uint256 constant USDC_DECIMALS = 1e6;

    /*//////////////////////////////////////////////////////////////
                          INTEREST CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    function test_calculateInterest_OneYear_5Percent() public pure {
        uint256 principal = 100_000 * USDC_DECIMALS; // $100,000 USDC
        uint256 rate = 0.05e18; // 5% APY
        uint256 time = 365 days;

        uint256 interest = FixedPointMath.calculateInterest(principal, rate, time);

        // Expected: $100,000 * 5% * 1 year = $5,000
        assertEq(interest, 5_000 * USDC_DECIMALS);
    }

    function test_calculateInterest_OneMonth_5Percent() public pure {
        uint256 principal = 100_000 * USDC_DECIMALS;
        uint256 rate = 0.05e18;
        uint256 time = 30 days;

        uint256 interest = FixedPointMath.calculateInterest(principal, rate, time);

        // Expected: $100,000 * 5% * (30/365) ≈ $410.96
        // Exact: 100000 * 0.05 * 30/365 = 410.958904...
        assertApproxEqRel(interest, 410_958904, 0.001e18); // 0.1% tolerance
    }

    function test_calculateInterest_90Days_8Percent() public pure {
        uint256 principal = 1_000_000 * USDC_DECIMALS; // $1M
        uint256 rate = 0.08e18; // 8% APY
        uint256 time = 90 days;

        uint256 interest = FixedPointMath.calculateInterest(principal, rate, time);

        // Expected: $1,000,000 * 8% * (90/365) ≈ $19,726.03
        assertApproxEqRel(interest, 19_726_027397, 0.001e18);
    }

    function test_calculateInterest_ZeroPrincipal() public pure {
        uint256 interest = FixedPointMath.calculateInterest(0, 0.05e18, 365 days);
        assertEq(interest, 0);
    }

    function test_calculateInterest_ZeroRate() public pure {
        uint256 interest = FixedPointMath.calculateInterest(100_000e6, 0, 365 days);
        assertEq(interest, 0);
    }

    function test_calculateInterest_ZeroTime() public pure {
        uint256 interest = FixedPointMath.calculateInterest(100_000e6, 0.05e18, 0);
        assertEq(interest, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            WAD OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_wadMul_Basic() public pure {
        // 2 * 3 = 6 (in WAD)
        uint256 result = FixedPointMath.wadMul(2e18, 3e18);
        assertEq(result, 6e18);
    }

    function test_wadMul_Decimals() public pure {
        // 1.5 * 2.5 = 3.75
        uint256 result = FixedPointMath.wadMul(1.5e18, 2.5e18);
        assertEq(result, 3.75e18);
    }

    function test_wadMul_Percentage() public pure {
        // $100 * 10% = $10
        uint256 result = FixedPointMath.wadMul(100e18, 0.10e18);
        assertEq(result, 10e18);
    }

    function test_wadDiv_Basic() public pure {
        // 6 / 2 = 3
        uint256 result = FixedPointMath.wadDiv(6e18, 2e18);
        assertEq(result, 3e18);
    }

    function test_wadDiv_Decimals() public pure {
        // 10 / 4 = 2.5
        uint256 result = FixedPointMath.wadDiv(10e18, 4e18);
        assertEq(result, 2.5e18);
    }

    /*//////////////////////////////////////////////////////////////
                          RATE CONVERSIONS
    //////////////////////////////////////////////////////////////*/

    function test_bpsToWad_100bps() public pure {
        // 100 bps = 1%
        uint256 result = FixedPointMath.bpsToWad(100);
        assertEq(result, 0.01e18);
    }

    function test_bpsToWad_500bps() public pure {
        // 500 bps = 5%
        uint256 result = FixedPointMath.bpsToWad(500);
        assertEq(result, 0.05e18);
    }

    function test_bpsToWad_10000bps() public pure {
        // 10000 bps = 100%
        uint256 result = FixedPointMath.bpsToWad(10000);
        assertEq(result, 1e18);
    }

    function test_wadToBps_1Percent() public pure {
        uint256 result = FixedPointMath.wadToBps(0.01e18);
        assertEq(result, 100);
    }

    function test_wadToBps_5Percent() public pure {
        uint256 result = FixedPointMath.wadToBps(0.05e18);
        assertEq(result, 500);
    }

    function test_bpsWadRoundTrip() public pure {
        uint256 originalBps = 350; // 3.5%
        uint256 wad = FixedPointMath.bpsToWad(originalBps);
        uint256 backToBps = FixedPointMath.wadToBps(wad);
        assertEq(backToBps, originalBps);
    }

    /*//////////////////////////////////////////////////////////////
                          UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_absDiff_AGreaterThanB() public pure {
        uint256 result = FixedPointMath.absDiff(100, 30);
        assertEq(result, 70);
    }

    function test_absDiff_BGreaterThanA() public pure {
        uint256 result = FixedPointMath.absDiff(30, 100);
        assertEq(result, 70);
    }

    function test_absDiff_Equal() public pure {
        uint256 result = FixedPointMath.absDiff(50, 50);
        assertEq(result, 0);
    }

    function test_toInt256_Success() public pure {
        int256 result = FixedPointMath.toInt256(100);
        assertEq(result, 100);
    }

    function test_toInt256_MaxValue() public pure {
        uint256 maxInt = uint256(type(int256).max);
        int256 result = FixedPointMath.toInt256(maxInt);
        assertEq(result, type(int256).max);
    }

    function test_toInt256_RevertOnOverflow() public {
        uint256 tooLarge = uint256(type(int256).max) + 1;
        vm.expectRevert("Value exceeds int256 max");
        this.externalToInt256(tooLarge);
    }

    // Helper to make library call external for vm.expectRevert
    function externalToInt256(uint256 value) external pure returns (int256) {
        return FixedPointMath.toInt256(value);
    }

    function test_toUint256_Success() public pure {
        uint256 result = FixedPointMath.toUint256(100);
        assertEq(result, 100);
    }

    function test_toUint256_RevertOnNegative() public {
        vm.expectRevert("Value is negative");
        this.externalToUint256(-1);
    }

    // Helper to make library call external for vm.expectRevert
    function externalToUint256(int256 value) external pure returns (uint256) {
        return FixedPointMath.toUint256(value);
    }

    function test_abs_Positive() public pure {
        uint256 result = FixedPointMath.abs(100);
        assertEq(result, 100);
    }

    function test_abs_Negative() public pure {
        uint256 result = FixedPointMath.abs(-100);
        assertEq(result, 100);
    }

    function test_abs_Zero() public pure {
        uint256 result = FixedPointMath.abs(0);
        assertEq(result, 0);
    }

    function test_min() public pure {
        assertEq(FixedPointMath.min(10, 20), 10);
        assertEq(FixedPointMath.min(20, 10), 10);
        assertEq(FixedPointMath.min(10, 10), 10);
    }

    function test_max() public pure {
        assertEq(FixedPointMath.max(10, 20), 20);
        assertEq(FixedPointMath.max(20, 10), 20);
        assertEq(FixedPointMath.max(10, 10), 10);
    }

    /*//////////////////////////////////////////////////////////////
                        PERCENTAGE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    function test_percentageOf_10Percent() public pure {
        uint256 result = FixedPointMath.percentageOf(1000e18, 0.10e18);
        assertEq(result, 100e18);
    }

    function test_percentageOf_50Percent() public pure {
        uint256 result = FixedPointMath.percentageOf(1000e18, 0.50e18);
        assertEq(result, 500e18);
    }

    function test_isWithinTolerance_Within() public pure {
        // 105 is within 10% of 100
        bool result = FixedPointMath.isWithinTolerance(105e18, 100e18, 0.10e18);
        assertTrue(result);
    }

    function test_isWithinTolerance_Outside() public pure {
        // 115 is NOT within 10% of 100
        bool result = FixedPointMath.isWithinTolerance(115e18, 100e18, 0.10e18);
        assertFalse(result);
    }

    function test_isWithinTolerance_Exact() public pure {
        bool result = FixedPointMath.isWithinTolerance(100e18, 100e18, 0.01e18);
        assertTrue(result);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_wadMul_Commutative(uint128 a, uint128 b) public pure {
        uint256 result1 = FixedPointMath.wadMul(uint256(a), uint256(b));
        uint256 result2 = FixedPointMath.wadMul(uint256(b), uint256(a));
        assertEq(result1, result2);
    }

    function testFuzz_bpsWadRoundTrip(uint16 bps) public pure {
        vm.assume(bps <= 10000); // Max 100%
        uint256 wad = FixedPointMath.bpsToWad(bps);
        uint256 backToBps = FixedPointMath.wadToBps(wad);
        assertEq(backToBps, bps);
    }

    function testFuzz_absDiff_Symmetric(uint128 a, uint128 b) public pure {
        uint256 result1 = FixedPointMath.absDiff(uint256(a), uint256(b));
        uint256 result2 = FixedPointMath.absDiff(uint256(b), uint256(a));
        assertEq(result1, result2);
    }

    function testFuzz_calculateInterest_Bounded(
        uint64 principal,
        uint64 rate,
        uint32 time
    ) public pure {
        vm.assume(principal > 0);
        vm.assume(rate <= 1e18); // Max 100% APY
        vm.assume(time <= 365 days);

        uint256 interest = FixedPointMath.calculateInterest(
            uint256(principal) * 1e6, // Scale to USDC
            uint256(rate),
            uint256(time)
        );

        // Interest should never exceed principal (at 100% APY for 1 year)
        assertTrue(interest <= uint256(principal) * 1e6);
    }
}
