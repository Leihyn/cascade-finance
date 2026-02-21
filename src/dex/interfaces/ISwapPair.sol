// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISwapPair
/// @notice Interface for the DEX trading pair (AMM pool)
/// @dev Based on Uniswap V2 Pair pattern with constant product formula
interface ISwapPair {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // Note: ERC20 functions (name, symbol, decimals, totalSupply, balanceOf, allowance,
    // approve, transfer, transferFrom, permit) are implemented via SwapERC20 inheritance

    /*//////////////////////////////////////////////////////////////
                            PAIR CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum liquidity locked forever to prevent division by zero
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    /// @notice The factory that created this pair
    function factory() external view returns (address);

    /// @notice First token in the pair (sorted by address)
    function token0() external view returns (address);

    /// @notice Second token in the pair (sorted by address)
    function token1() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            PAIR STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current reserves and last update timestamp
    /// @return reserve0 Reserve of token0
    /// @return reserve1 Reserve of token1
    /// @return blockTimestampLast Last block timestamp when reserves were updated
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    /// @notice Cumulative price of token0 (for TWAP)
    function price0CumulativeLast() external view returns (uint256);

    /// @notice Cumulative price of token1 (for TWAP)
    function price1CumulativeLast() external view returns (uint256);

    /// @notice Last k value (reserve0 * reserve1) for fee calculation
    function kLast() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            PAIR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add liquidity and mint LP tokens
    /// @param to Recipient of LP tokens
    /// @return liquidity Amount of LP tokens minted
    function mint(address to) external returns (uint256 liquidity);

    /// @notice Remove liquidity and burn LP tokens
    /// @param to Recipient of underlying tokens
    /// @return amount0 Amount of token0 returned
    /// @return amount1 Amount of token1 returned
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap tokens
    /// @param amount0Out Amount of token0 to send out
    /// @param amount1Out Amount of token1 to send out
    /// @param to Recipient of output tokens
    /// @param data Callback data for flash swaps
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Force reserves to match balances
    function skim(address to) external;

    /// @notice Force balances to match reserves
    function sync() external;

    /// @notice Initialize the pair (called once by factory)
    function initialize(address token0_, address token1_) external;
}
