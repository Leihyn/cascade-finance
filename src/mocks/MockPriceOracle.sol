// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lending/interfaces/IPriceOracle.sol";

/// @title MockPriceOracle
/// @notice Mock price oracle for testing
/// @dev Allows manual setting of prices for any asset
contract MockPriceOracle is IPriceOracle {
    mapping(address => uint256) public prices;
    mapping(address => uint256) public timestamps;

    /// @notice Set the price for an asset
    /// @param asset The asset address
    /// @param price The price in 18 decimals
    function setPrice(address asset, uint256 price) external {
        prices[asset] = price;
        timestamps[asset] = block.timestamp;
    }

    /// @notice Set price with custom timestamp
    /// @param asset The asset address
    /// @param price The price in 18 decimals
    /// @param timestamp The timestamp for the price
    function setPriceWithTimestamp(address asset, uint256 price, uint256 timestamp) external {
        prices[asset] = price;
        timestamps[asset] = timestamp;
    }

    /// @inheritdoc IPriceOracle
    function getPrice(address asset) external view override returns (uint256) {
        return prices[asset];
    }

    /// @inheritdoc IPriceOracle
    function getPriceWithTimestamp(address asset) external view override returns (uint256 price, uint256 updatedAt) {
        return (prices[asset], timestamps[asset]);
    }

    /// @inheritdoc IPriceOracle
    function isPriceValid(address asset) external view override returns (bool) {
        return prices[asset] > 0 && timestamps[asset] > 0;
    }
}
