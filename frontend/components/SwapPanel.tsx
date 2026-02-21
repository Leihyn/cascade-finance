"use client";

import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits, parseUnits } from "viem";
import { FullStackContracts } from "@/lib/wagmi";

const ROUTER_ABI = [
  {
    name: "swapExactTokensForTokens",
    type: "function",
    inputs: [
      { name: "amountIn", type: "uint256" },
      { name: "amountOutMin", type: "uint256" },
      { name: "path", type: "address[]" },
      { name: "to", type: "address" },
      { name: "deadline", type: "uint256" },
    ],
    outputs: [{ name: "amounts", type: "uint256[]" }],
    stateMutability: "nonpayable",
  },
  {
    name: "getAmountsOut",
    type: "function",
    inputs: [
      { name: "amountIn", type: "uint256" },
      { name: "path", type: "address[]" },
    ],
    outputs: [{ name: "amounts", type: "uint256[]" }],
    stateMutability: "view",
  },
] as const;

const ERC20_ABI = [
  {
    name: "approve",
    type: "function",
    inputs: [{ name: "spender", type: "address" }, { name: "amount", type: "uint256" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    name: "balanceOf",
    type: "function",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    name: "allowance",
    type: "function",
    inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;

interface SwapPanelProps {
  contracts: FullStackContracts;
}

type SwapStep = "idle" | "approving" | "swapping";

export function SwapPanel({ contracts }: SwapPanelProps) {
  const { address } = useAccount();
  const [amountIn, setAmountIn] = useState("");
  const [tokenIn, setTokenIn] = useState<"usdc" | "weth">("usdc");
  const [swapStep, setSwapStep] = useState<SwapStep>("idle");

  const { writeContract, data: hash, isPending, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const tokenInAddress = tokenIn === "usdc" ? contracts.usdc : contracts.weth;
  const tokenOutAddress = tokenIn === "usdc" ? contracts.weth : contracts.usdc;
  const tokenInDecimals = tokenIn === "usdc" ? 6 : 18;
  const tokenOutDecimals = tokenIn === "usdc" ? 18 : 6;

  const { data: usdcBalance, refetch: refetchUsdc } = useReadContract({
    address: contracts.usdc,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: wethBalance, refetch: refetchWeth } = useReadContract({
    address: contracts.weth,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenInAddress,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, contracts.swapRouter] : undefined,
  });

  const amountInWei = amountIn ? parseUnits(amountIn, tokenInDecimals) : BigInt(0);
  const { data: amountsOut } = useReadContract({
    address: contracts.swapRouter,
    abi: ROUTER_ABI,
    functionName: "getAmountsOut",
    args: amountInWei > 0 ? [amountInWei, [tokenInAddress, tokenOutAddress]] : undefined,
  });

  const amountOut = amountsOut ? amountsOut[1] : BigInt(0);
  const needsApproval = !allowance || allowance < amountInWei;

  useEffect(() => {
    if (isSuccess && swapStep === "approving") {
      refetchAllowance().then(() => {
        reset();
        setSwapStep("swapping");
        const minOut = amountOut * BigInt(995) / BigInt(1000);
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200);
        writeContract({
          address: contracts.swapRouter,
          abi: ROUTER_ABI,
          functionName: "swapExactTokensForTokens",
          args: [amountInWei, minOut, [tokenInAddress, tokenOutAddress], address!, deadline],
        });
      });
    } else if (isSuccess && swapStep === "swapping") {
      setSwapStep("idle");
      setAmountIn("");
      refetchUsdc();
      refetchWeth();
      refetchAllowance();
    }
  }, [isSuccess, swapStep, amountOut, amountInWei, tokenInAddress, tokenOutAddress, address, contracts.swapRouter, writeContract, reset, refetchAllowance, refetchUsdc, refetchWeth]);

  const handleSwap = () => {
    if (!amountIn || !address || amountInWei === BigInt(0)) return;
    if (needsApproval) {
      setSwapStep("approving");
      writeContract({
        address: tokenInAddress,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [contracts.swapRouter, amountInWei],
      });
    } else {
      setSwapStep("swapping");
      const minOut = amountOut * BigInt(995) / BigInt(1000);
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200);
      writeContract({
        address: contracts.swapRouter,
        abi: ROUTER_ABI,
        functionName: "swapExactTokensForTokens",
        args: [amountInWei, minOut, [tokenInAddress, tokenOutAddress], address, deadline],
      });
    }
  };

  const switchTokens = () => {
    setTokenIn(tokenIn === "usdc" ? "weth" : "usdc");
    setAmountIn("");
    setSwapStep("idle");
  };

  const getButtonText = () => {
    if (isPending || isConfirming) {
      if (swapStep === "approving") return "Approving...";
      if (swapStep === "swapping") return "Swapping...";
      return "Processing...";
    }
    if (needsApproval && amountInWei > 0) return "Approve & Swap";
    return "Swap";
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-6">
      <h2 className="text-xl font-bold mb-6">Swap</h2>
      <div className="grid grid-cols-2 gap-4 mb-6 text-sm">
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className="text-gray-500">USDC Balance</div>
          <div className="font-mono">{usdcBalance ? formatUnits(usdcBalance, 6) : "0"}</div>
        </div>
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className="text-gray-500">WETH Balance</div>
          <div className="font-mono">{wethBalance ? formatUnits(wethBalance, 18) : "0"}</div>
        </div>
      </div>
      <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 mb-2">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm text-gray-500">From</span>
          <span className="text-xs text-gray-400">
            Balance: {tokenIn === "usdc" ? (usdcBalance ? formatUnits(usdcBalance, 6) : "0") : (wethBalance ? formatUnits(wethBalance, 18) : "0")}
          </span>
        </div>
        <div className="flex gap-3">
          <input type="number" value={amountIn} onChange={(e) => setAmountIn(e.target.value)} placeholder="0.00" className="flex-1 bg-transparent text-2xl font-mono focus:outline-none" />
          <div className="px-4 py-2 bg-gray-200 dark:bg-gray-700 rounded-lg font-medium">{tokenIn.toUpperCase()}</div>
        </div>
      </div>
      <div className="flex justify-center -my-2 relative z-10">
        <button onClick={switchTokens} className="p-2 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" /></svg>
        </button>
      </div>
      <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 mb-6">
        <div className="flex justify-between items-center mb-2"><span className="text-sm text-gray-500">To (estimated)</span></div>
        <div className="flex gap-3">
          <div className="flex-1 text-2xl font-mono text-gray-400">{amountOut > 0 ? formatUnits(amountOut, tokenOutDecimals) : "0.00"}</div>
          <div className="px-4 py-2 bg-gray-200 dark:bg-gray-700 rounded-lg font-medium">{tokenIn === "usdc" ? "WETH" : "USDC"}</div>
        </div>
      </div>
      <button onClick={handleSwap} disabled={isPending || isConfirming || !amountIn || amountOut === BigInt(0)} className="w-full py-3 rounded-lg font-medium text-white bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed">{getButtonText()}</button>
      {isSuccess && swapStep === "idle" && (<div className="mt-4 p-3 bg-green-50 dark:bg-green-900/20 rounded-lg text-green-600 text-sm">Swap successful!</div>)}
      <div className="mt-4 text-xs text-gray-500 text-center">0.3% swap fee | Slippage tolerance: 0.5%</div>
    </div>
  );
}
