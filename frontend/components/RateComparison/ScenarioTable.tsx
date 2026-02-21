"use client";

import { useMemo } from "react";

interface Props {
  fixedRate: number;
  currentFloatingRate: number;
  notional: number;
  maturityDays: number;
  isPayingFixed: boolean;
}

interface Scenario {
  name: string;
  rateChange: number;
  projectedRate: number;
  pnl: number;
  color: string;
  bgColor: string;
}

export function ScenarioTable({
  fixedRate,
  currentFloatingRate,
  notional,
  maturityDays,
  isPayingFixed,
}: Props) {
  const scenarios = useMemo<Scenario[]>(() => {
    const calculatePnL = (floatingRate: number): number => {
      const rateDiff = isPayingFixed
        ? floatingRate - fixedRate
        : fixedRate - floatingRate;
      const annualizedPnL = (notional * rateDiff) / 100;
      return (annualizedPnL * maturityDays) / 365;
    };

    return [
      {
        name: "Bull (+2%)",
        rateChange: 2,
        projectedRate: currentFloatingRate + 2,
        pnl: calculatePnL(currentFloatingRate + 2),
        color: "text-green-600 dark:text-green-400",
        bgColor: "bg-green-50 dark:bg-green-900/20",
      },
      {
        name: "Mild Bull (+1%)",
        rateChange: 1,
        projectedRate: currentFloatingRate + 1,
        pnl: calculatePnL(currentFloatingRate + 1),
        color: "text-green-600 dark:text-green-400",
        bgColor: "bg-green-50/50 dark:bg-green-900/10",
      },
      {
        name: "Neutral",
        rateChange: 0,
        projectedRate: currentFloatingRate,
        pnl: calculatePnL(currentFloatingRate),
        color: "text-gray-600 dark:text-gray-400",
        bgColor: "bg-gray-50 dark:bg-gray-800",
      },
      {
        name: "Mild Bear (-1%)",
        rateChange: -1,
        projectedRate: Math.max(0, currentFloatingRate - 1),
        pnl: calculatePnL(Math.max(0, currentFloatingRate - 1)),
        color: "text-red-600 dark:text-red-400",
        bgColor: "bg-red-50/50 dark:bg-red-900/10",
      },
      {
        name: "Bear (-2%)",
        rateChange: -2,
        projectedRate: Math.max(0, currentFloatingRate - 2),
        pnl: calculatePnL(Math.max(0, currentFloatingRate - 2)),
        color: "text-red-600 dark:text-red-400",
        bgColor: "bg-red-50 dark:bg-red-900/20",
      },
    ];
  }, [fixedRate, currentFloatingRate, notional, maturityDays, isPayingFixed]);

  return (
    <div className="space-y-3">
      <div className="flex justify-between items-center">
        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
          Scenario Analysis
        </span>
        <span className="text-xs text-gray-500 dark:text-gray-400">
          {maturityDays} day period
        </span>
      </div>

      <div className="overflow-hidden rounded-lg border border-gray-200 dark:border-gray-700">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-100 dark:bg-gray-800">
              <th className="text-left px-3 py-2 font-medium text-gray-600 dark:text-gray-400">
                Scenario
              </th>
              <th className="text-right px-3 py-2 font-medium text-gray-600 dark:text-gray-400">
                Rate
              </th>
              <th className="text-right px-3 py-2 font-medium text-gray-600 dark:text-gray-400">
                P&L
              </th>
            </tr>
          </thead>
          <tbody>
            {scenarios.map((scenario, index) => (
              <tr
                key={scenario.name}
                className={`${scenario.bgColor} ${
                  index !== scenarios.length - 1
                    ? "border-b border-gray-200 dark:border-gray-700"
                    : ""
                }`}
              >
                <td className="px-3 py-2 text-gray-700 dark:text-gray-300">
                  <div className="flex items-center gap-2">
                    <span
                      className={`w-2 h-2 rounded-full ${
                        scenario.rateChange > 0
                          ? "bg-green-500"
                          : scenario.rateChange < 0
                          ? "bg-red-500"
                          : "bg-gray-400"
                      }`}
                    />
                    {scenario.name}
                  </div>
                </td>
                <td className="px-3 py-2 text-right text-gray-700 dark:text-gray-300">
                  {scenario.projectedRate.toFixed(2)}%
                </td>
                <td className={`px-3 py-2 text-right font-medium ${
                  scenario.pnl >= 0
                    ? "text-green-600 dark:text-green-400"
                    : "text-red-600 dark:text-red-400"
                }`}>
                  {scenario.pnl >= 0 ? "+" : ""}${Math.abs(scenario.pnl).toFixed(2)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="text-xs text-gray-500 dark:text-gray-400">
        {isPayingFixed
          ? "Pay Fixed positions profit when floating rates rise above your fixed rate."
          : "Pay Floating positions profit when floating rates fall below your fixed rate."}
      </p>
    </div>
  );
}
