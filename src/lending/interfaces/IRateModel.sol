// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRateModel
/// @notice Interface for interest rate models used by the lending protocol
/// @dev Implements a utilization-based rate model similar to Compound's JumpRateModel
interface IRateModel {
    /// @notice Calculate the current borrow rate per second
    /// @param cash The amount of cash in the market
    /// @param borrows The amount of borrows in the market
    /// @param reserves The amount of reserves in the market
    /// @return The borrow rate per second, scaled by 1e18
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256);

    /// @notice Calculate the current supply rate per second
    /// @param cash The amount of cash in the market
    /// @param borrows The amount of borrows in the market
    /// @param reserves The amount of reserves in the market
    /// @param reserveFactorMantissa The current reserve factor, scaled by 1e18
    /// @return The supply rate per second, scaled by 1e18
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256);

    /// @notice Calculate the utilization rate
    /// @param cash The amount of cash in the market
    /// @param borrows The amount of borrows in the market
    /// @param reserves The amount of reserves in the market
    /// @return The utilization rate, scaled by 1e18
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external pure returns (uint256);
}
