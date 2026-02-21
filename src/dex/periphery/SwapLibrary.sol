// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/ISwapPair.sol";
import "../interfaces/ISwapFactory.sol";

/// @title SwapLibrary
/// @notice Helper functions for DEX operations
/// @dev Based on Uniswap V2 Library
library SwapLibrary {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientAmount();
    error InsufficientLiquidity();
    error InvalidPath();
    error IdenticalAddresses();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                          PAIR HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sort tokens by address
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return token0 Lower address token
    /// @return token1 Higher address token
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    /// @notice Get the pair address for two tokens
    /// @param factory Factory address
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return pair The pair address
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        return ISwapFactory(factory).getPair(tokenA, tokenB);
    }

    /// @notice Get reserves for a pair
    /// @param factory Factory address
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return reserveA Reserve of tokenA
    /// @return reserveB Reserve of tokenB
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = ISwapPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /*//////////////////////////////////////////////////////////////
                          QUOTE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Given an input amount and reserves, calculate the equivalent output amount
    /// @param amountA Input amount
    /// @param reserveA Reserve of input token
    /// @param reserveB Reserve of output token
    /// @return amountB Equivalent output amount
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        if (amountA == 0) revert InsufficientAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        amountB = (amountA * reserveB) / reserveA;
    }

    /// @notice Calculate output amount for exact input (including 0.3% fee)
    /// @param amountIn Exact input amount
    /// @param reserveIn Reserve of input token
    /// @param reserveOut Reserve of output token
    /// @return amountOut Output amount
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice Calculate input amount for exact output (including 0.3% fee)
    /// @param amountOut Exact output amount
    /// @param reserveIn Reserve of input token
    /// @param reserveOut Reserve of output token
    /// @return amountIn Required input amount
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /// @notice Calculate amounts out for a swap path
    /// @param factory Factory address
    /// @param amountIn Input amount
    /// @param path Array of token addresses in swap path
    /// @return amounts Array of amounts for each step
    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /// @notice Calculate amounts in for a swap path
    /// @param factory Factory address
    /// @param amountOut Output amount
    /// @param path Array of token addresses in swap path
    /// @return amounts Array of amounts for each step
    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
