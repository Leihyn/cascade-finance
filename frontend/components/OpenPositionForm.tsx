"use client";

import { useState, useEffect } from "react";
import { useWriteContract, useReadContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { POSITION_MANAGER_ABI, ERC20_ABI, RATE_ORACLE_ABI } from "@/lib/abis";
import { useToast, parseError } from "./ui/Toast";
import { RateComparison } from "./RateComparison";

interface Props {
  contracts: {
    positionManager: `0x${string}`;
    rateOracle: `0x${string}`;
    usdc: `0x${string}`;
  };
}

export function OpenPositionForm({ contracts }: Props) {
  const { address } = useAccount();
  const { addToast } = useToast();
  const [isPayingFixed, setIsPayingFixed] = useState(true);
  const [notional, setNotional] = useState("10000");
  const [fixedRate, setFixedRate] = useState("5");
  const [maturityDays, setMaturityDays] = useState("90");
  const [margin, setMargin] = useState("1000");
  const [txStatus, setTxStatus] = useState<string | null>(null);
  const [showRateAnalysis, setShowRateAnalysis] = useState(false);

  const { writeContract, isPending, data: hash, error, reset } = useWriteContract();

  // Wait for transaction receipt
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  // Get current floating rate
  const { data: currentRate } = useReadContract({
    address: contracts.rateOracle,
    abi: RATE_ORACLE_ABI,
    functionName: "getCurrentRate",
  });

  // Get USDC allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: contracts.usdc,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address!, contracts.positionManager],
  });

  // Handle transaction status updates
  useEffect(() => {
    if (isPending) {
      setTxStatus("Waiting for wallet...");
    } else if (isConfirming) {
      setTxStatus("Confirming transaction...");
    } else if (isConfirmed) {
      setTxStatus(null);
      addToast({ type: "success", title: "Success", message: "Transaction confirmed!" });
      refetchAllowance();
      reset();
    } else if (error) {
      setTxStatus(null);
      addToast({ type: "error", title: "Error", message: parseError(error) });
      reset();
    }
  }, [isPending, isConfirming, isConfirmed, error, refetchAllowance, reset, addToast]);

  const handleApprove = () => {
    writeContract({
      address: contracts.usdc,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [contracts.positionManager, parseUnits("1000000", 6)],
    });
  };

  const handleOpenPosition = () => {
    writeContract({
      address: contracts.positionManager,
      abi: POSITION_MANAGER_ABI,
      functionName: "openPosition",
      args: [
        isPayingFixed,
        parseUnits(notional, 6),
        parseUnits(fixedRate, 16), // Convert % to WAD (5% = 0.05e18)
        BigInt(maturityDays),
        parseUnits(margin, 6),
      ],
    });
  };

  const needsApproval = !allowance || allowance < parseUnits(margin, 6);
  const isWorking = isPending || isConfirming;
  const floatingRateDisplay = currentRate
    ? (Number(formatUnits(currentRate, 18)) * 100).toFixed(2)
    : "...";

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl p-4 sm:p-6 border border-gray-200 dark:border-gray-800">
      <h2 className="text-lg sm:text-xl font-semibold mb-4 sm:mb-6">Open Position</h2>

      {/* Position Type Toggle */}
      <div className="flex gap-2 mb-4 sm:mb-6">
        <button
          onClick={() => setIsPayingFixed(true)}
          className={`flex-1 py-3 min-h-[48px] rounded-lg font-medium transition ${
            isPayingFixed
              ? "bg-indigo-600 text-white"
              : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
          }`}
        >
          Pay Fixed
        </button>
        <button
          onClick={() => setIsPayingFixed(false)}
          className={`flex-1 py-3 min-h-[48px] rounded-lg font-medium transition ${
            !isPayingFixed
              ? "bg-purple-600 text-white"
              : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
          }`}
        >
          Pay Floating
        </button>
      </div>

      {/* Rate Display */}
      <div className="grid grid-cols-2 gap-3 sm:gap-4 mb-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
        <div>
          <div className="text-sm text-gray-500 dark:text-gray-400">You Pay</div>
          <div className="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white">
            {isPayingFixed ? `${fixedRate}%` : `${floatingRateDisplay}%`}
          </div>
          <div className="text-xs text-gray-400 dark:text-gray-500">
            {isPayingFixed ? "Fixed" : "Floating"}
          </div>
        </div>
        <div>
          <div className="text-sm text-gray-500 dark:text-gray-400">You Receive</div>
          <div className="text-xl sm:text-2xl font-bold text-green-600 dark:text-green-400">
            {isPayingFixed ? `${floatingRateDisplay}%` : `${fixedRate}%`}
          </div>
          <div className="text-xs text-gray-400 dark:text-gray-500">
            {isPayingFixed ? "Floating" : "Fixed"}
          </div>
        </div>
      </div>

      {/* Rate Analysis Toggle */}
      <button
        type="button"
        onClick={() => setShowRateAnalysis(!showRateAnalysis)}
        className="w-full flex items-center justify-between px-4 py-3 mb-4 sm:mb-6 text-sm text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/30 rounded-lg hover:bg-indigo-100 dark:hover:bg-indigo-900/50 transition"
      >
        <span className="font-medium">
          {showRateAnalysis ? "Hide Rate Analysis" : "View Rate Analysis"}
        </span>
        <svg
          className={`w-5 h-5 transition-transform ${showRateAnalysis ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {/* Rate Comparison Component */}
      {showRateAnalysis && currentRate && (
        <div className="mb-4 sm:mb-6">
          <RateComparison
            currentFloatingRate={Number(formatUnits(currentRate, 18)) * 100}
            fixedRate={Number(fixedRate)}
            notional={Number(notional)}
            maturityDays={Number(maturityDays)}
            isPayingFixed={isPayingFixed}
          />
        </div>
      )}

      {/* Form Fields */}
      <div className="space-y-4">
        <div>
          <label className="block text-sm text-gray-600 dark:text-gray-400 mb-2">
            Notional Amount (USDC)
          </label>
          <input
            type="number"
            value={notional}
            onChange={(e) => setNotional(e.target.value)}
            className="w-full bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg px-4 py-3 min-h-[48px] text-base text-gray-900 dark:text-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            placeholder="10000"
          />
        </div>

        <div>
          <label className="block text-sm text-gray-600 dark:text-gray-400 mb-2">
            Fixed Rate (%)
          </label>
          <input
            type="number"
            step="0.1"
            value={fixedRate}
            onChange={(e) => setFixedRate(e.target.value)}
            className="w-full bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg px-4 py-3 min-h-[48px] text-base text-gray-900 dark:text-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            placeholder="5.0"
          />
        </div>

        <div>
          <label className="block text-sm text-gray-600 dark:text-gray-400 mb-2">Maturity</label>
          <select
            value={maturityDays}
            onChange={(e) => setMaturityDays(e.target.value)}
            className="w-full bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg px-4 py-3 min-h-[48px] text-base text-gray-900 dark:text-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
          >
            <option value="30">30 Days</option>
            <option value="90">90 Days</option>
            <option value="180">180 Days</option>
            <option value="365">365 Days</option>
          </select>
        </div>

        <div>
          <label className="block text-sm text-gray-600 dark:text-gray-400 mb-2">
            Margin (USDC)
          </label>
          <input
            type="number"
            value={margin}
            onChange={(e) => setMargin(e.target.value)}
            className="w-full bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg px-4 py-3 min-h-[48px] text-base text-gray-900 dark:text-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            placeholder="1000"
          />
          <div className="text-xs text-gray-500 mt-1">
            Min: {(Number(notional) * 0.1).toLocaleString()} USDC (10% of notional)
          </div>
        </div>
      </div>

      {/* Transaction Status */}
      {txStatus && (
        <div className={`mt-4 p-3 rounded-lg text-center ${
          txStatus.includes("Error") ? "bg-red-100 dark:bg-red-900/50 text-red-700 dark:text-red-300" :
          txStatus.includes("confirmed") ? "bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-300" :
          "bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300"
        }`}>
          {txStatus}
        </div>
      )}

      {/* Action Button */}
      <div className="mt-6">
        {needsApproval ? (
          <button
            onClick={handleApprove}
            disabled={isWorking}
            className="w-full py-4 min-h-[56px] bg-yellow-500 hover:bg-yellow-400 text-white rounded-lg font-semibold transition disabled:opacity-50"
          >
            {isWorking ? (isConfirming ? "Confirming..." : "Approving...") : "Approve USDC"}
          </button>
        ) : (
          <button
            onClick={handleOpenPosition}
            disabled={isWorking}
            className="w-full py-4 min-h-[56px] bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-semibold transition disabled:opacity-50"
          >
            {isWorking ? (isConfirming ? "Confirming..." : "Opening...") : "Open Position"}
          </button>
        )}
      </div>
    </div>
  );
}
