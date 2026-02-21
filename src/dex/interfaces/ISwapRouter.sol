// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISwapRouter
/// @notice Interface for the DEX router (user-facing swap and liquidity functions)
/// @dev Based on Uniswap V2 Router pattern
interface ISwapRouter {
    /// @notice Get the factory address
    function factory() external view returns (address);

    /// @notice Get the WETH address
    function WETH() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                          LIQUIDITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add liquidity to a pair
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param amountADesired Desired amount of tokenA to add
    /// @param amountBDesired Desired amount of tokenB to add
    /// @param amountAMin Minimum amount of tokenA (slippage protection)
    /// @param amountBMin Minimum amount of tokenB (slippage protection)
    /// @param to Recipient of LP tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amountA Actual amount of tokenA added
    /// @return amountB Actual amount of tokenB added
    /// @return liquidity Amount of LP tokens minted
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Add liquidity with ETH
    /// @param token Token to pair with ETH
    /// @param amountTokenDesired Desired amount of token to add
    /// @param amountTokenMin Minimum amount of token (slippage protection)
    /// @param amountETHMin Minimum amount of ETH (slippage protection)
    /// @param to Recipient of LP tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amountToken Actual amount of token added
    /// @return amountETH Actual amount of ETH added
    /// @return liquidity Amount of LP tokens minted
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    /// @notice Remove liquidity from a pair
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum amount of tokenA to receive
    /// @param amountBMin Minimum amount of tokenB to receive
    /// @param to Recipient of underlying tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amountA Amount of tokenA received
    /// @return amountB Amount of tokenB received
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Remove liquidity with ETH
    /// @param token Token paired with ETH
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountTokenMin Minimum amount of token to receive
    /// @param amountETHMin Minimum amount of ETH to receive
    /// @param to Recipient of underlying tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amountToken Amount of token received
    /// @return amountETH Amount of ETH received
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /*//////////////////////////////////////////////////////////////
                            SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap exact input for minimum output
    /// @param amountIn Exact input amount
    /// @param amountOutMin Minimum output amount
    /// @param path Token swap path
    /// @param to Recipient of output tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amounts Array of amounts for each step in the path
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap maximum input for exact output
    /// @param amountOut Exact output amount
    /// @param amountInMax Maximum input amount
    /// @param path Token swap path
    /// @param to Recipient of output tokens
    /// @param deadline Transaction deadline timestamp
    /// @return amounts Array of amounts for each step in the path
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap exact ETH for minimum tokens
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap exact tokens for minimum ETH
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap maximum tokens for exact ETH
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap maximum ETH for exact tokens
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    /*//////////////////////////////////////////////////////////////
                            QUOTE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Quote amount out for amount in
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    /// @notice Get amount out for exact input
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut);

    /// @notice Get amount in for exact output
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountIn);

    /// @notice Get amounts out for a path
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    /// @notice Get amounts in for a path
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}
