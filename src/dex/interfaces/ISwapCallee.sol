// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISwapCallee
/// @notice Interface for flash swap callbacks
/// @dev Implement this interface to receive flash swap callbacks
interface ISwapCallee {
    /// @notice Called by the pair during a flash swap
    /// @param sender The address that initiated the swap
    /// @param amount0 Amount of token0 sent to this contract
    /// @param amount1 Amount of token1 sent to this contract
    /// @param data Arbitrary data passed through from swap call
    function swapCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
