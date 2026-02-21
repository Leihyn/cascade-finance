"use client";

import { useMemo } from "react";
import { BreakevenAnalysis } from "./BreakevenAnalysis";
import { ScenarioTable } from "./ScenarioTable";
import { RateChart } from "./RateChart";

interface Props {
  currentFloatingRate: number; // As percentage (e.g., 5.5 for 5.5%)
  fixedRate: number; // As percentage
  notional: number; // In USDC (e.g., 10000)
  maturityDays: number;
  isPayingFixed: boolean;
}

export function RateComparison({
  currentFloatingRate,
  fixedRate,
  notional,
  maturityDays,
  isPayingFixed,
}: Props) {
  // Calculate rate differential
  const rateDiff = useMemo(() => {
    if (isPayingFixed) {
      // Pay fixed, receive floating: profit when floating > fixed
      return currentFloatingRate - fixedRate;
    } else {
      // Pay floating, receive fixed: profit when fixed > floating
      return fixedRate - currentFloatingRate;
    }
  }, [currentFloatingRate, fixedRate, isPayingFixed]);

  // Calculate annualized PnL based on current rates
  const annualizedPnL = useMemo(() => {
    return (notional * rateDiff) / 100;
  }, [notional, rateDiff]);

  // Calculate PnL for maturity period
  const periodPnL = useMemo(() => {
    return (annualizedPnL * maturityDays) / 365;
  }, [annualizedPnL, maturityDays]);

  // Determine position outlook
  const outlook = useMemo(() => {
    if (Math.abs(rateDiff) < 0.1) return "neutral";
    return rateDiff > 0 ? "favorable" : "unfavorable";
  }, [rateDiff]);

  const outlookColors = {
    favorable: "text-green-600 dark:text-green-400",
    unfavorable: "text-red-600 dark:text-red-400",
    neutral: "text-yellow-600 dark:text-yellow-400",
  };

  const outlookBgColors = {
    favorable: "bg-green-50 dark:bg-green-900/30",
    unfavorable: "bg-red-50 dark:bg-red-900/30",
    neutral: "bg-yellow-50 dark:bg-yellow-900/30",
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl p-4 sm:p-6 border border-gray-200 dark:border-gray-800 space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">Rate Analysis</h3>
        <span
          className={`text-xs px-2 py-1 rounded ${outlookBgColors[outlook]} ${outlookColors[outlook]}`}
        >
          {outlook === "favorable" && "Favorable"}
          {outlook === "unfavorable" && "Unfavorable"}
          {outlook === "neutral" && "Neutral"}
        </span>
      </div>

      {/* Rate Comparison Summary */}
      <div className={`rounded-lg p-4 ${outlookBgColors[outlook]}`}>
        <div className="grid grid-cols-3 gap-4 text-center">
          <div>
            <div className="text-xs text-gray-500 dark:text-gray-400 mb-1">
              You Pay
            </div>
            <div className="text-lg font-bold">
              {isPayingFixed ? fixedRate.toFixed(2) : currentFloatingRate.toFixed(2)}%
            </div>
            <div className="text-xs text-gray-500">
              {isPayingFixed ? "Fixed" : "Floating"}
            </div>
          </div>
          <div className="flex items-center justify-center">
            <div className={`text-2xl font-bold ${outlookColors[outlook]}`}>
              {rateDiff >= 0 ? "+" : ""}
              {rateDiff.toFixed(2)}%
            </div>
          </div>
          <div>
            <div className="text-xs text-gray-500 dark:text-gray-400 mb-1">
              You Receive
            </div>
            <div className="text-lg font-bold">
              {isPayingFixed ? currentFloatingRate.toFixed(2) : fixedRate.toFixed(2)}%
            </div>
            <div className="text-xs text-gray-500">
              {isPayingFixed ? "Floating" : "Fixed"}
            </div>
          </div>
        </div>
      </div>

      {/* Projected PnL */}
      <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm text-gray-600 dark:text-gray-400">
            Projected P&L ({maturityDays} days)
          </span>
          <span className={`text-lg font-bold ${periodPnL >= 0 ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`}>
            {periodPnL >= 0 ? "+" : ""}${Math.abs(periodPnL).toFixed(2)}
          </span>
        </div>
        <div className="text-xs text-gray-500 dark:text-gray-400">
          Based on current floating rate of {currentFloatingRate.toFixed(2)}% remaining constant
        </div>
      </div>

      {/* Breakeven Analysis */}
      <BreakevenAnalysis
        fixedRate={fixedRate}
        currentFloatingRate={currentFloatingRate}
        isPayingFixed={isPayingFixed}
      />

      {/* Scenario Analysis */}
      <ScenarioTable
        fixedRate={fixedRate}
        currentFloatingRate={currentFloatingRate}
        notional={notional}
        maturityDays={maturityDays}
        isPayingFixed={isPayingFixed}
      />

      {/* Rate Chart */}
      <RateChart
        fixedRate={fixedRate}
        currentFloatingRate={currentFloatingRate}
        isPayingFixed={isPayingFixed}
      />
    </div>
  );
}
