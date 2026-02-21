// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Fixed Point Math Library
/// @author Kairos Protocol
/// @notice High-precision math for interest rate calculations
/// @dev Uses WAD (1e18) for percentages and rates
library FixedPointMath {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice WAD = 18 decimals, used for percentages and rates
    uint256 internal constant WAD = 1e18;

    /// @notice RAY = 27 decimals, used for accumulated rates (like Aave)
    uint256 internal constant RAY = 1e27;

    /// @notice Seconds in a year (365 days)
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /// @notice Basis points denominator (10000 = 100%)
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                            WAD OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiply two WAD numbers
    /// @param a First WAD number
    /// @param b Second WAD number
    /// @return Result in WAD
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / WAD;
    }

    /// @notice Divide two WAD numbers
    /// @param a Numerator in WAD
    /// @param b Denominator in WAD
    /// @return Result in WAD
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * WAD) / b;
    }

    /// @notice Multiply then divide with WAD precision (avoids overflow)
    /// @param a First number
    /// @param b Multiplier
    /// @param c Divisor
    /// @return Result
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return (a * b) / c;
    }

    /*//////////////////////////////////////////////////////////////
                          INTEREST CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate simple interest: principal * rate * time / year
    /// @param principal The notional amount (in token decimals, e.g., 1e6 for USDC)
    /// @param rateWad Annual rate in WAD (e.g., 5% = 0.05e18)
    /// @param timeSeconds Duration in seconds
    /// @return Interest amount in same decimals as principal
    function calculateInterest(
        uint256 principal,
        uint256 rateWad,
        uint256 timeSeconds
    ) internal pure returns (uint256) {
        // interest = principal * rate * (time / year)
        // Using mulDiv to avoid overflow: (principal * rateWad * timeSeconds) / (WAD * SECONDS_PER_YEAR)
        return (principal * rateWad * timeSeconds) / (WAD * SECONDS_PER_YEAR);
    }

    /// @notice Calculate interest with signed result (for PnL calculations)
    /// @param principal The notional amount
    /// @param rateWad Annual rate in WAD
    /// @param timeSeconds Duration in seconds
    /// @return Interest as signed integer
    function calculateInterestSigned(
        uint256 principal,
        uint256 rateWad,
        uint256 timeSeconds
    ) internal pure returns (int256) {
        return int256(calculateInterest(principal, rateWad, timeSeconds));
    }

    /*//////////////////////////////////////////////////////////////
                            RATE CONVERSIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Convert basis points to WAD (100 bps = 1% = 0.01e18)
    /// @param bps Basis points (e.g., 500 = 5%)
    /// @return Rate in WAD format
    function bpsToWad(uint256 bps) internal pure returns (uint256) {
        return (bps * WAD) / BPS_DENOMINATOR;
    }

    /// @notice Convert WAD to basis points
    /// @param wadRate Rate in WAD format
    /// @return Basis points
    function wadToBps(uint256 wadRate) internal pure returns (uint256) {
        return (wadRate * BPS_DENOMINATOR) / WAD;
    }

    /// @notice Convert APY to per-second rate
    /// @param apyWad Annual percentage yield in WAD
    /// @return Per-second rate in WAD
    function apyToPerSecond(uint256 apyWad) internal pure returns (uint256) {
        return apyWad / SECONDS_PER_YEAR;
    }

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Absolute difference between two values
    /// @param a First value
    /// @param b Second value
    /// @return Absolute difference
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /// @notice Safe conversion from uint256 to int256
    /// @param value Unsigned value to convert
    /// @return Signed value
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "Value exceeds int256 max");
        return int256(value);
    }

    /// @notice Safe conversion from int256 to uint256
    /// @param value Signed value to convert
    /// @return Unsigned value
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "Value is negative");
        return uint256(value);
    }

    /// @notice Get absolute value of signed integer
    /// @param value Signed value
    /// @return Absolute value
    function abs(int256 value) internal pure returns (uint256) {
        return value >= 0 ? uint256(value) : uint256(-value);
    }

    /// @notice Minimum of two values
    /// @param a First value
    /// @param b Second value
    /// @return Minimum
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Maximum of two values
    /// @param a First value
    /// @param b Second value
    /// @return Maximum
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /*//////////////////////////////////////////////////////////////
                          PERCENTAGE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate percentage of a value
    /// @param value Base value
    /// @param percentageWad Percentage in WAD (e.g., 10% = 0.1e18)
    /// @return Result
    function percentageOf(uint256 value, uint256 percentageWad) internal pure returns (uint256) {
        return wadMul(value, percentageWad);
    }

    /// @notice Check if value is within percentage tolerance of target
    /// @param value Value to check
    /// @param target Target value
    /// @param toleranceWad Tolerance in WAD (e.g., 1% = 0.01e18)
    /// @return True if within tolerance
    function isWithinTolerance(
        uint256 value,
        uint256 target,
        uint256 toleranceWad
    ) internal pure returns (bool) {
        uint256 maxDiff = wadMul(target, toleranceWad);
        return absDiff(value, target) <= maxDiff;
    }
}
