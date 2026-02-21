// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/ISwapRouter.sol";
import "../interfaces/ISwapFactory.sol";
import "../interfaces/ISwapPair.sol";
import "./SwapLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SwapRouter
/// @notice Router for DEX swaps and liquidity operations
/// @dev Based on Uniswap V2 Router with security improvements
contract SwapRouter is ISwapRouter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Expired();
    error InsufficientAAmount();
    error InsufficientBAmount();
    error InsufficientOutputAmount();
    error ExcessiveInputAmount();
    error InvalidPath();

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable factory;
    address public immutable WETH;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address factory_, address WETH_) {
        factory = factory_;
        WETH = WETH_;
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        // Create pair if it doesn't exist
        if (ISwapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ISwapFactory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = SwapLibrary.getReserves(factory, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = SwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = SwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if (amountAOptimal < amountAMin) revert InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /// @inheritdoc ISwapRouter
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        address pair = SwapLibrary.pairFor(factory, tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = ISwapPair(pair).mint(to);
    }

    /// @inheritdoc ISwapRouter
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        address pair = SwapLibrary.pairFor(factory, token, WETH);
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);

        // Wrap ETH
        (bool success,) = WETH.call{value: amountETH}("");
        require(success, "SwapRouter: ETH_TRANSFER_FAILED");
        IERC20(WETH).safeTransfer(pair, amountETH);

        liquidity = ISwapPair(pair).mint(to);

        // Refund excess ETH
        if (msg.value > amountETH) {
            (success,) = msg.sender.call{value: msg.value - amountETH}("");
            require(success, "SwapRouter: ETH_REFUND_FAILED");
        }
    }

    /// @inheritdoc ISwapRouter
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = SwapLibrary.pairFor(factory, tokenA, tokenB);
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = ISwapPair(pair).burn(to);
        (address token0,) = SwapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountB < amountBMin) revert InsufficientBAmount();
    }

    /// @inheritdoc ISwapRouter
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        IERC20(token).safeTransfer(to, amountToken);

        // Unwrap WETH
        (bool success,) = WETH.call(abi.encodeWithSignature("withdraw(uint256)", amountETH));
        require(success, "SwapRouter: WETH_WITHDRAW_FAILED");
        (success,) = to.call{value: amountETH}("");
        require(success, "SwapRouter: ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                          SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _swap(uint256[] memory amounts, address[] memory path, address to_) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? SwapLibrary.pairFor(factory, output, path[i + 2]) : to_;
            ISwapPair(SwapLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /// @inheritdoc ISwapRouter
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = SwapLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        IERC20(path[0]).safeTransferFrom(msg.sender, SwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    /// @inheritdoc ISwapRouter
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = SwapLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert ExcessiveInputAmount();
        IERC20(path[0]).safeTransferFrom(msg.sender, SwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    /// @inheritdoc ISwapRouter
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != WETH) revert InvalidPath();
        amounts = SwapLibrary.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();

        // Wrap ETH
        (bool success,) = WETH.call{value: amounts[0]}("");
        require(success, "SwapRouter: ETH_TRANSFER_FAILED");
        IERC20(WETH).safeTransfer(SwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    /// @inheritdoc ISwapRouter
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != WETH) revert InvalidPath();
        amounts = SwapLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();

        IERC20(path[0]).safeTransferFrom(msg.sender, SwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));

        // Unwrap WETH
        (bool success,) = WETH.call(abi.encodeWithSignature("withdraw(uint256)", amounts[amounts.length - 1]));
        require(success, "SwapRouter: WETH_WITHDRAW_FAILED");
        (success,) = to.call{value: amounts[amounts.length - 1]}("");
        require(success, "SwapRouter: ETH_TRANSFER_FAILED");
    }

    /// @inheritdoc ISwapRouter
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != WETH) revert InvalidPath();
        amounts = SwapLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert ExcessiveInputAmount();

        IERC20(path[0]).safeTransferFrom(msg.sender, SwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));

        // Unwrap WETH
        (bool success,) = WETH.call(abi.encodeWithSignature("withdraw(uint256)", amounts[amounts.length - 1]));
        require(success, "SwapRouter: WETH_WITHDRAW_FAILED");
        (success,) = to.call{value: amounts[amounts.length - 1]}("");
        require(success, "SwapRouter: ETH_TRANSFER_FAILED");
    }

    /// @inheritdoc ISwapRouter
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != WETH) revert InvalidPath();
        amounts = SwapLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > msg.value) revert ExcessiveInputAmount();

        // Wrap ETH
        (bool success,) = WETH.call{value: amounts[0]}("");
        require(success, "SwapRouter: ETH_TRANSFER_FAILED");
        IERC20(WETH).safeTransfer(SwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);

        // Refund excess ETH
        if (msg.value > amounts[0]) {
            (success,) = msg.sender.call{value: msg.value - amounts[0]}("");
            require(success, "SwapRouter: ETH_REFUND_FAILED");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          QUOTE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISwapRouter
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        return SwapLibrary.quote(amountA, reserveA, reserveB);
    }

    /// @inheritdoc ISwapRouter
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        return SwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @inheritdoc ISwapRouter
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountIn) {
        return SwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /// @inheritdoc ISwapRouter
    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        return SwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    /// @inheritdoc ISwapRouter
    function getAmountsIn(uint256 amountOut, address[] memory path) public view returns (uint256[] memory amounts) {
        return SwapLibrary.getAmountsIn(factory, amountOut, path);
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        // Only accept ETH from WETH contract
        assert(msg.sender == WETH);
    }
}
