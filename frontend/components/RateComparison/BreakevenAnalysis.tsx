"use client";

import { useMemo } from "react";

interface Props {
  fixedRate: number;
  currentFloatingRate: number;
  isPayingFixed: boolean;
}

export function BreakevenAnalysis({
  fixedRate,
  currentFloatingRate,
  isPayingFixed,
}: Props) {
  // For pay fixed: breakeven when floating = fixed
  // For pay floating: breakeven when floating = fixed
  // The breakeven rate is always the fixed rate
  const breakevenRate = fixedRate;

  // Calculate how far current rate is from breakeven
  const distanceFromBreakeven = useMemo(() => {
    const diff = currentFloatingRate - breakevenRate;
    if (isPayingFixed) {
      // Pay fixed profits when floating > fixed
      return diff;
    } else {
      // Pay floating profits when floating < fixed
      return -diff;
    }
  }, [currentFloatingRate, breakevenRate, isPayingFixed]);

  // Calculate position on visual scale (0-100)
  // Scale: breakeven is at 50%, show +-3% range
  const range = 3; // 3% range on each side
  const position = useMemo(() => {
    const normalized = ((currentFloatingRate - breakevenRate) / range) * 50;
    return Math.max(0, Math.min(100, 50 + normalized));
  }, [currentFloatingRate, breakevenRate]);

  const isInProfit = distanceFromBreakeven > 0;
  const isProfitable = isInProfit;

  return (
    <div className="space-y-3">
      <div className="flex justify-between items-center">
        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
          Breakeven Analysis
        </span>
        <span className="text-xs text-gray-500 dark:text-gray-400">
          Breakeven: {breakevenRate.toFixed(2)}%
        </span>
      </div>

      {/* Visual breakeven indicator */}
      <div className="relative">
        {/* Track */}
        <div className="h-3 bg-gradient-to-r from-red-200 via-gray-200 to-green-200 dark:from-red-900/50 dark:via-gray-700 dark:to-green-900/50 rounded-full overflow-hidden">
          {/* Profit zone highlight */}
          <div
            className={`absolute top-0 h-full transition-all duration-300 ${
              isPayingFixed
                ? "right-0 bg-gradient-to-l from-green-400/30 to-transparent"
                : "left-0 bg-gradient-to-r from-green-400/30 to-transparent"
            }`}
            style={{ width: "50%" }}
          />
        </div>

        {/* Breakeven marker */}
        <div
          className="absolute top-0 w-0.5 h-3 bg-gray-600 dark:bg-gray-400"
          style={{ left: "50%" }}
        />

        {/* Current rate indicator */}
        <div
          className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 transition-all duration-300"
          style={{ left: `${position}%` }}
        >
          <div
            className={`w-4 h-4 rounded-full border-2 ${
              isProfitable
                ? "bg-green-500 border-green-600"
                : "bg-red-500 border-red-600"
            }`}
          />
        </div>
      </div>

      {/* Labels */}
      <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400">
        <span>{isPayingFixed ? "Loss Zone" : "Profit Zone"}</span>
        <span className="font-medium">Breakeven</span>
        <span>{isPayingFixed ? "Profit Zone" : "Loss Zone"}</span>
      </div>

      {/* Status message */}
      <div
        className={`text-sm ${
          isProfitable
            ? "text-green-600 dark:text-green-400"
            : "text-red-600 dark:text-red-400"
        }`}
      >
        {isProfitable ? (
          <>
            Current floating rate is{" "}
            <span className="font-semibold">
              {Math.abs(distanceFromBreakeven).toFixed(2)}%
            </span>{" "}
            {isPayingFixed ? "above" : "below"} breakeven
          </>
        ) : (
          <>
            Need floating rate to move{" "}
            <span className="font-semibold">
              {Math.abs(distanceFromBreakeven).toFixed(2)}%
            </span>{" "}
            {isPayingFixed ? "higher" : "lower"} to break even
          </>
        )}
      </div>
    </div>
  );
}
