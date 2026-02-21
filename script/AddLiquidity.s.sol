// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISwapRouter {
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
}

contract AddLiquidity is Script {
    // Base Sepolia addresses
    address constant USDC = 0xE7D8ADd69537883fAccD068fC798794093B4a9b6;
    address constant WETH = 0x3058A6a96221BbEBD030bB36a13f53000b45d0aD;
    address constant SWAP_ROUTER = 0xA32bFE3Ea5282A8EecdcC2378569938E3b30C4A4;

    function run() external {
        uint256 usdcAmount = 100_000 * 1e6;  // 100k USDC
        uint256 wethAmount = 50 * 1e18;       // 50 WETH (sets price at ~2000 USDC/WETH)

        vm.startBroadcast();

        // Approve tokens
        IERC20(USDC).approve(SWAP_ROUTER, usdcAmount);
        IERC20(WETH).approve(SWAP_ROUTER, wethAmount);

        console.log("Approved USDC:", usdcAmount / 1e6);
        console.log("Approved WETH:", wethAmount / 1e18);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = ISwapRouter(SWAP_ROUTER).addLiquidity(
            USDC,
            WETH,
            usdcAmount,
            wethAmount,
            usdcAmount * 95 / 100,  // 5% slippage
            wethAmount * 95 / 100,
            msg.sender,
            block.timestamp + 3600
        );

        console.log("Added USDC:", amountA / 1e6);
        console.log("Added WETH:", amountB / 1e18);
        console.log("LP tokens received:", liquidity);

        vm.stopBroadcast();
    }
}
