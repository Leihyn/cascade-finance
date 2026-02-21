// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";

/// @title MockRateSource
/// @notice Mock rate source for testing
contract MockRateSource is IRateSource {
    uint256 public supplyRate;
    uint256 public borrowRate;

    constructor(uint256 _supplyRate, uint256 _borrowRate) {
        supplyRate = _supplyRate;
        borrowRate = _borrowRate;
    }

    function setSupplyRate(uint256 _rate) external {
        supplyRate = _rate;
    }

    function setBorrowRate(uint256 _rate) external {
        borrowRate = _rate;
    }

    function setRates(uint256 _supplyRate, uint256 _borrowRate) external {
        supplyRate = _supplyRate;
        borrowRate = _borrowRate;
    }

    function getSupplyRate() external view override returns (uint256) {
        return supplyRate;
    }

    function getBorrowRate() external view override returns (uint256) {
        return borrowRate;
    }
}
