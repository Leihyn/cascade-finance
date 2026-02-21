// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockRateSource
/// @notice A mock rate source for testnet that returns configurable rates
/// @dev Only for testing - DO NOT use in production
contract MockRateSource is IRateSource, Ownable {
    /// @notice Current supply rate (annualized, in WAD - 1e18 = 100%)
    uint256 public supplyRate;

    /// @notice Current borrow rate (annualized, in WAD)
    uint256 public borrowRate;

    /// @notice Default rates: 5% supply, 8% borrow
    constructor() Ownable(msg.sender) {
        supplyRate = 0.05e18; // 5% APY
        borrowRate = 0.08e18; // 8% APY
    }

    /// @inheritdoc IRateSource
    function getSupplyRate() external view override returns (uint256) {
        return supplyRate;
    }

    /// @inheritdoc IRateSource
    function getBorrowRate() external view override returns (uint256) {
        return borrowRate;
    }

    /// @notice Update the mock supply rate
    /// @param newRate New rate in WAD (1e18 = 100%)
    function setSupplyRate(uint256 newRate) external onlyOwner {
        supplyRate = newRate;
    }

    /// @notice Update the mock borrow rate
    /// @param newRate New rate in WAD
    function setBorrowRate(uint256 newRate) external onlyOwner {
        borrowRate = newRate;
    }

    /// @notice Update both rates at once
    /// @param newSupplyRate New supply rate in WAD
    /// @param newBorrowRate New borrow rate in WAD
    function setRates(uint256 newSupplyRate, uint256 newBorrowRate) external onlyOwner {
        supplyRate = newSupplyRate;
        borrowRate = newBorrowRate;
    }
}
