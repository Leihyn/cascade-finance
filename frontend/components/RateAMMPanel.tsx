"use client";

import { useState } from "react";
import { useAccount } from "wagmi";

interface RateAMMPanelProps {
  contracts: any;
}

export function RateAMMPanel({ contracts }: RateAMMPanelProps) {
  const { address } = useAccount();
  const [mode, setMode] = useState<"trade" | "liquidity">("trade");
  const [isPayingFixed, setIsPayingFixed] = useState(true);
  const [notional, setNotional] = useState("");
  const [liquidityAmount, setLiquidityAmount] = useState("");

  // Mock data - would come from contract reads
  const poolData = {
    currentRate: "5.25",
    targetRate: "5.00",
    totalLiquidity: "1,250,000",
    fixedLiquidity: "625,000",
    floatingLiquidity: "625,000",
    fee: "0.30",
    yourShares: "0",
    yourValue: "0",
  };

  const handleTrade = async () => {
    // Would call IRSPool.swap()
    console.log("Trading:", { isPayingFixed, notional });
  };

  const handleAddLiquidity = async () => {
    // Would call IRSPool.addLiquidity()
    console.log("Adding liquidity:", liquidityAmount);
  };

  const handleRemoveLiquidity = async () => {
    // Would call IRSPool.removeLiquidity()
    console.log("Removing liquidity");
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-bold">Rate AMM</h2>
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-lg p-1">
          <button
            onClick={() => setMode("trade")}
            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
              mode === "trade"
                ? "bg-white dark:bg-gray-700 shadow-sm"
                : "text-gray-500"
            }`}
          >
            Trade
          </button>
          <button
            onClick={() => setMode("liquidity")}
            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
              mode === "liquidity"
                ? "bg-white dark:bg-gray-700 shadow-sm"
                : "text-gray-500"
            }`}
          >
            Liquidity
          </button>
        </div>
      </div>

      {/* Pool Stats */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
          <div className="text-sm text-gray-500 mb-1">Current Rate</div>
          <div className="text-2xl font-bold text-indigo-600">
            {poolData.currentRate}%
          </div>
          <div className="text-xs text-gray-400">
            Target: {poolData.targetRate}%
          </div>
        </div>
        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
          <div className="text-sm text-gray-500 mb-1">Total Liquidity</div>
          <div className="text-2xl font-bold">${poolData.totalLiquidity}</div>
          <div className="text-xs text-gray-400">USDC</div>
        </div>
      </div>

      {/* Liquidity Distribution */}
      <div className="mb-6">
        <div className="flex justify-between text-sm mb-2">
          <span className="text-gray-500">Fixed: ${poolData.fixedLiquidity}</span>
          <span className="text-gray-500">Floating: ${poolData.floatingLiquidity}</span>
        </div>
        <div className="h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
          <div className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 w-1/2" />
        </div>
      </div>

      {mode === "trade" ? (
        <>
          {/* Trade Direction */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Position</label>
            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setIsPayingFixed(true)}
                className={`p-3 rounded-lg border-2 transition-colors ${
                  isPayingFixed
                    ? "border-indigo-500 bg-indigo-50 dark:bg-indigo-900/20"
                    : "border-gray-200 dark:border-gray-700"
                }`}
              >
                <div className="font-medium">Pay Fixed</div>
                <div className="text-xs text-gray-500">Receive Floating</div>
              </button>
              <button
                onClick={() => setIsPayingFixed(false)}
                className={`p-3 rounded-lg border-2 transition-colors ${
                  !isPayingFixed
                    ? "border-indigo-500 bg-indigo-50 dark:bg-indigo-900/20"
                    : "border-gray-200 dark:border-gray-700"
                }`}
              >
                <div className="font-medium">Pay Floating</div>
                <div className="text-xs text-gray-500">Receive Fixed</div>
              </button>
            </div>
          </div>

          {/* Notional Input */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Notional Amount</label>
            <div className="relative">
              <input
                type="number"
                value={notional}
                onChange={(e) => setNotional(e.target.value)}
                placeholder="0.00"
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              />
              <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500">
                USDC
              </span>
            </div>
          </div>

          {/* Quote */}
          {notional && (
            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 mb-4">
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-500">You Will {isPayingFixed ? "Pay" : "Receive"}</span>
                <span className="font-medium">{poolData.currentRate}% Fixed</span>
              </div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-500">Fee ({poolData.fee}%)</span>
                <span className="font-medium">
                  {(parseFloat(notional) * 0.003).toFixed(2)} USDC
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Slippage Impact</span>
                <span className="font-medium text-green-500">~0.01%</span>
              </div>
            </div>
          )}

          {/* Trade Button */}
          <button
            onClick={handleTrade}
            disabled={!notional}
            className="w-full py-3 bg-gradient-to-r from-indigo-500 to-purple-500 text-white font-medium rounded-lg hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPayingFixed ? "Pay Fixed Rate" : "Receive Fixed Rate"}
          </button>
        </>
      ) : (
        <>
          {/* Your Position */}
          <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 mb-4">
            <div className="text-sm text-gray-500 mb-2">Your LP Position</div>
            <div className="flex justify-between">
              <div>
                <div className="text-lg font-bold">{poolData.yourShares}</div>
                <div className="text-xs text-gray-500">LP Shares</div>
              </div>
              <div className="text-right">
                <div className="text-lg font-bold">${poolData.yourValue}</div>
                <div className="text-xs text-gray-500">Value</div>
              </div>
            </div>
          </div>

          {/* Add Liquidity */}
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Add Liquidity</label>
            <div className="relative">
              <input
                type="number"
                value={liquidityAmount}
                onChange={(e) => setLiquidityAmount(e.target.value)}
                placeholder="0.00"
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              />
              <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500">
                USDC
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={handleAddLiquidity}
              disabled={!liquidityAmount}
              className="py-3 bg-gradient-to-r from-indigo-500 to-purple-500 text-white font-medium rounded-lg hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              Add Liquidity
            </button>
            <button
              onClick={handleRemoveLiquidity}
              disabled={poolData.yourShares === "0"}
              className="py-3 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-medium rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors disabled:opacity-50"
            >
              Remove
            </button>
          </div>

          {/* LP Info */}
          <div className="mt-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg text-sm text-blue-700 dark:text-blue-300">
            <p>
              LP providers earn {poolData.fee}% fees on all trades. Liquidity is split
              between fixed and floating sides to facilitate rate swaps.
            </p>
          </div>
        </>
      )}
    </div>
  );
}
