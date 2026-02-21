// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPriceOracle
/// @notice Interface for price oracle used by Comet lending
/// @dev Returns prices in base token units (e.g., USDC) with 18 decimals
interface IPriceOracle {
    /// @notice Get the price of an asset in terms of base token
    /// @param asset The asset to price
    /// @return price Price in base token units, scaled by 1e18
    /// @dev Example: if 1 WETH = 3000 USDC, returns 3000e18
    function getPrice(address asset) external view returns (uint256 price);

    /// @notice Get price with timestamp for staleness validation
    /// @dev Phase 1 Security: Required for Chainlink-style staleness checks
    /// @param asset The asset to price
    /// @return price Price in base token units, scaled by 1e18
    /// @return updatedAt Timestamp when price was last updated
    function getPriceWithTimestamp(address asset) external view returns (uint256 price, uint256 updatedAt);

    /// @notice Check if oracle has valid price for asset
    /// @param asset The asset to check
    /// @return valid True if price is available and not stale
    function isPriceValid(address asset) external view returns (bool valid);
}
