"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits, parseUnits } from "viem";
import { FullStackContracts } from "@/lib/wagmi";

// Simplified ABIs
const COMET_ABI = [
  {
    name: "supply",
    type: "function",
    inputs: [{ name: "asset", type: "address" }, { name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    name: "withdraw",
    type: "function",
    inputs: [{ name: "asset", type: "address" }, { name: "amount", type: "uint256" }],
    outputs: [],
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
    name: "borrowBalanceOf",
    type: "function",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    name: "getSupplyRate",
    type: "function",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }],
    stateMutability: "view",
  },
  {
    name: "getBorrowRate",
    type: "function",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }],
    stateMutability: "view",
  },
  {
    name: "getUtilization",
    type: "function",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
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
] as const;

interface LendingPanelProps {
  contracts: FullStackContracts;
}

export function LendingPanel({ contracts }: LendingPanelProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const [activeTab, setActiveTab] = useState<"supply" | "withdraw">("supply");

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Read user balances
  const { data: supplyBalance } = useReadContract({
    address: contracts.comet,
    abi: COMET_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const { data: borrowBalance } = useReadContract({
    address: contracts.comet,
    abi: COMET_ABI,
    functionName: "borrowBalanceOf",
    args: address ? [address] : undefined,
  });

  const { data: walletBalance } = useReadContract({
    address: contracts.usdc,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  // Read rates
  const { data: supplyRate } = useReadContract({
    address: contracts.comet,
    abi: COMET_ABI,
    functionName: "getSupplyRate",
  });

  const { data: borrowRate } = useReadContract({
    address: contracts.comet,
    abi: COMET_ABI,
    functionName: "getBorrowRate",
  });

  const { data: utilization } = useReadContract({
    address: contracts.comet,
    abi: COMET_ABI,
    functionName: "getUtilization",
  });

  const handleSupply = async () => {
    if (!amount) return;
    const amountWei = parseUnits(amount, 6);

    // First approve
    writeContract({
      address: contracts.usdc,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [contracts.comet, amountWei],
    });
  };

  const handleWithdraw = async () => {
    if (!amount) return;
    const amountWei = parseUnits(amount, 6);

    writeContract({
      address: contracts.comet,
      abi: COMET_ABI,
      functionName: "withdraw",
      args: [contracts.usdc, amountWei],
    });
  };

  // Convert per-second rate to APY
  const formatAPY = (rate: bigint | undefined) => {
    if (!rate) return "0.00%";
    const annualRate = Number(rate) * 31536000; // seconds per year
    return ((annualRate / 1e18) * 100).toFixed(2) + "%";
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold">Lending Pool</h2>
        <div className="text-sm text-gray-500">
          Utilization: {utilization ? ((Number(utilization) / 1e18) * 100).toFixed(1) : "0"}%
        </div>
      </div>

      {/* Rate Display */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
          <div className="text-sm text-gray-500 dark:text-gray-400">Supply APY</div>
          <div className="text-2xl font-bold text-green-600 dark:text-green-400">
            {formatAPY(supplyRate)}
          </div>
        </div>
        <div className="bg-red-50 dark:bg-red-900/20 rounded-lg p-4">
          <div className="text-sm text-gray-500 dark:text-gray-400">Borrow APY</div>
          <div className="text-2xl font-bold text-red-600 dark:text-red-400">
            {formatAPY(borrowRate)}
          </div>
        </div>
      </div>

      {/* User Balances */}
      <div className="grid grid-cols-3 gap-4 mb-6 text-sm">
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className="text-gray-500">Wallet</div>
          <div className="font-mono">
            {walletBalance ? formatUnits(walletBalance, 6) : "0"} USDC
          </div>
        </div>
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className="text-gray-500">Supplied</div>
          <div className="font-mono text-green-600">
            {supplyBalance ? formatUnits(supplyBalance, 6) : "0"} USDC
          </div>
        </div>
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
          <div className="text-gray-500">Borrowed</div>
          <div className="font-mono text-red-600">
            {borrowBalance ? formatUnits(borrowBalance, 6) : "0"} USDC
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 dark:border-gray-700 mb-4">
        <button
          onClick={() => setActiveTab("supply")}
          className={`px-4 py-2 font-medium ${
            activeTab === "supply"
              ? "text-green-600 border-b-2 border-green-600"
              : "text-gray-500"
          }`}
        >
          Supply
        </button>
        <button
          onClick={() => setActiveTab("withdraw")}
          className={`px-4 py-2 font-medium ${
            activeTab === "withdraw"
              ? "text-red-600 border-b-2 border-red-600"
              : "text-gray-500"
          }`}
        >
          Withdraw
        </button>
      </div>

      {/* Amount Input */}
      <div className="mb-4">
        <label className="block text-sm text-gray-500 mb-1">Amount (USDC)</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.00"
          className="w-full px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent focus:ring-2 focus:ring-indigo-500"
        />
      </div>

      {/* Action Button */}
      <button
        onClick={activeTab === "supply" ? handleSupply : handleWithdraw}
        disabled={isPending || isConfirming || !amount}
        className={`w-full py-3 rounded-lg font-medium text-white ${
          activeTab === "supply"
            ? "bg-green-600 hover:bg-green-700"
            : "bg-red-600 hover:bg-red-700"
        } disabled:opacity-50 disabled:cursor-not-allowed`}
      >
        {isPending || isConfirming
          ? "Processing..."
          : activeTab === "supply"
          ? "Supply USDC"
          : "Withdraw USDC"}
      </button>

      {isSuccess && (
        <div className="mt-4 p-3 bg-green-50 dark:bg-green-900/20 rounded-lg text-green-600 text-sm">
          Transaction confirmed!
        </div>
      )}
    </div>
  );
}
