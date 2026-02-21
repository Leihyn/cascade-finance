// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISwapFactory
/// @notice Interface for the DEX factory that creates trading pairs
/// @dev Based on Uniswap V2 Factory pattern
interface ISwapFactory {
    /// @notice Emitted when a new pair is created
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairCount);

    /// @notice Get the pair address for two tokens
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pair The pair address (address(0) if doesn't exist)
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    /// @notice Get all pairs
    /// @param index Index in the allPairs array
    /// @return pair The pair address at the given index
    function allPairs(uint256 index) external view returns (address pair);

    /// @notice Get the total number of pairs
    /// @return The number of pairs created
    function allPairsLength() external view returns (uint256);

    /// @notice Create a new pair
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pair The newly created pair address
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /// @notice Get the fee recipient address
    /// @return The address receiving protocol fees
    function feeTo() external view returns (address);

    /// @notice Get the fee setter address
    /// @return The address that can set the fee recipient
    function feeToSetter() external view returns (address);

    /// @notice Set the fee recipient
    /// @param newFeeTo The new fee recipient address
    function setFeeTo(address newFeeTo) external;

    /// @notice Set the fee setter
    /// @param newFeeToSetter The new fee setter address
    function setFeeToSetter(address newFeeToSetter) external;
}
