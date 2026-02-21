// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateModel.sol";

/// @title JumpRateModel
/// @notice Interest rate model with a kink (jump) at a target utilization
/// @dev Based on Compound's JumpRateModel - rates increase faster above the kink
contract JumpRateModel is IRateModel {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The scale for mantissa calculations (1e18 = 100%)
    uint256 public constant MANTISSA_ONE = 1e18;

    /// @notice Seconds per year for annualized rate calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                            PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice The base interest rate per second when utilization is 0
    uint256 public immutable baseRatePerSecond;

    /// @notice The multiplier per second for utilization rate below the kink
    uint256 public immutable multiplierPerSecond;

    /// @notice The multiplier per second for utilization rate above the kink
    uint256 public immutable jumpMultiplierPerSecond;

    /// @notice The utilization rate at which the jump multiplier kicks in (scaled by 1e18)
    uint256 public immutable kink;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event NewInterestParams(
        uint256 baseRatePerSecond,
        uint256 multiplierPerSecond,
        uint256 jumpMultiplierPerSecond,
        uint256 kink
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Construct an interest rate model
    /// @param baseRatePerYear_ The approximate target base APR (scaled by 1e18)
    /// @param multiplierPerYear_ The rate of increase per utilization below kink (scaled by 1e18)
    /// @param jumpMultiplierPerYear_ The rate of increase per utilization above kink (scaled by 1e18)
    /// @param kink_ The utilization point at which the jump multiplier is applied (scaled by 1e18)
    constructor(
        uint256 baseRatePerYear_,
        uint256 multiplierPerYear_,
        uint256 jumpMultiplierPerYear_,
        uint256 kink_
    ) {
        baseRatePerSecond = baseRatePerYear_ / SECONDS_PER_YEAR;
        multiplierPerSecond = multiplierPerYear_ / SECONDS_PER_YEAR;
        jumpMultiplierPerSecond = jumpMultiplierPerYear_ / SECONDS_PER_YEAR;
        kink = kink_;

        emit NewInterestParams(
            baseRatePerSecond,
            multiplierPerSecond,
            jumpMultiplierPerSecond,
            kink
        );
    }

    /*//////////////////////////////////////////////////////////////
                          RATE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRateModel
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure override returns (uint256) {
        // Utilization = borrows / (cash + borrows - reserves)
        if (borrows == 0) {
            return 0;
        }

        uint256 totalAssets = cash + borrows;
        if (totalAssets <= reserves) {
            return 0;
        }

        return (borrows * MANTISSA_ONE) / (totalAssets - reserves);
    }

    /// @inheritdoc IRateModel
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view override returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);

        if (util <= kink) {
            // Normal rate: baseRate + util * multiplier
            return baseRatePerSecond + (util * multiplierPerSecond) / MANTISSA_ONE;
        } else {
            // Rate at kink
            uint256 normalRate = baseRatePerSecond + (kink * multiplierPerSecond) / MANTISSA_ONE;

            // Excess utilization above kink
            uint256 excessUtil = util - kink;

            // Jump rate: normalRate + excessUtil * jumpMultiplier
            return normalRate + (excessUtil * jumpMultiplierPerSecond) / MANTISSA_ONE;
        }
    }

    /// @inheritdoc IRateModel
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) public view override returns (uint256) {
        // Supply rate = borrow rate * utilization * (1 - reserve factor)
        uint256 oneMinusReserveFactor = MANTISSA_ONE - reserveFactorMantissa;
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = (borrowRate * oneMinusReserveFactor) / MANTISSA_ONE;
        uint256 util = utilizationRate(cash, borrows, reserves);

        return (util * rateToPool) / MANTISSA_ONE;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get annualized borrow rate
    /// @param cash The amount of cash in the market
    /// @param borrows The amount of borrows in the market
    /// @param reserves The amount of reserves in the market
    /// @return The annual borrow rate scaled by 1e18
    function getBorrowRatePerYear(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256) {
        return getBorrowRate(cash, borrows, reserves) * SECONDS_PER_YEAR;
    }

    /// @notice Get annualized supply rate
    /// @param cash The amount of cash in the market
    /// @param borrows The amount of borrows in the market
    /// @param reserves The amount of reserves in the market
    /// @param reserveFactorMantissa The current reserve factor
    /// @return The annual supply rate scaled by 1e18
    function getSupplyRatePerYear(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256) {
        return getSupplyRate(cash, borrows, reserves, reserveFactorMantissa) * SECONDS_PER_YEAR;
    }
}
