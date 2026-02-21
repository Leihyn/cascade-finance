// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRateSource
/// @notice Interface for interest rate data sources (Aave, Compound, etc.)
interface IRateSource {
    /// @notice Get the current supply/lending rate
    /// @return rate Annual rate in WAD (1e18 = 100%)
    function getSupplyRate() external view returns (uint256 rate);

    /// @notice Get the current borrow rate
    /// @return rate Annual rate in WAD
    function getBorrowRate() external view returns (uint256 rate);
}
