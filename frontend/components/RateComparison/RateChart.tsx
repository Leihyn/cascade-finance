"use client";

import { useMemo } from "react";

interface Props {
  fixedRate: number;
  currentFloatingRate: number;
  isPayingFixed: boolean;
}

export function RateChart({
  fixedRate,
  currentFloatingRate,
  isPayingFixed,
}: Props) {
  // Generate sample historical data points (simulated)
  const dataPoints = useMemo(() => {
    const points = [];
    const variance = 0.5; // Random variance
    let rate = currentFloatingRate - 1; // Start slightly lower

    for (let i = 0; i < 12; i++) {
      rate += (Math.random() - 0.45) * variance;
      rate = Math.max(0, rate); // Ensure non-negative
      points.push({
        month: i,
        rate: rate,
      });
    }

    // Ensure last point is current rate
    points[11] = { month: 11, rate: currentFloatingRate };

    return points;
  }, [currentFloatingRate]);

  // Calculate chart dimensions
  const minRate = Math.min(
    ...dataPoints.map((p) => p.rate),
    fixedRate - 1
  );
  const maxRate = Math.max(
    ...dataPoints.map((p) => p.rate),
    fixedRate + 1
  );
  const range = maxRate - minRate;

  // Convert rate to Y position (inverted for SVG)
  const rateToY = (rate: number): number => {
    return 100 - ((rate - minRate) / range) * 100;
  };

  // Generate SVG path for floating rate line
  const floatingPath = useMemo(() => {
    return dataPoints
      .map((point, index) => {
        const x = (index / 11) * 100;
        const y = rateToY(point.rate);
        return `${index === 0 ? "M" : "L"} ${x} ${y}`;
      })
      .join(" ");
  }, [dataPoints, minRate, range]);

  // Fixed rate Y position
  const fixedY = rateToY(fixedRate);

  // Determine profit zone
  const profitZone = isPayingFixed
    ? { y: 0, height: fixedY } // Above fixed line (higher floating = profit)
    : { y: fixedY, height: 100 - fixedY }; // Below fixed line (lower floating = profit)

  return (
    <div className="space-y-3">
      <div className="flex justify-between items-center">
        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
          Rate Projection
        </span>
        <div className="flex items-center gap-4 text-xs">
          <div className="flex items-center gap-1">
            <div className="w-3 h-0.5 bg-indigo-500" />
            <span className="text-gray-500 dark:text-gray-400">Floating</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-0.5 bg-purple-500 border-dashed" style={{ borderTop: '2px dashed' }} />
            <span className="text-gray-500 dark:text-gray-400">Fixed</span>
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="relative h-32 bg-gray-50 dark:bg-gray-800 rounded-lg overflow-hidden">
        <svg
          viewBox="0 0 100 100"
          preserveAspectRatio="none"
          className="absolute inset-0 w-full h-full"
        >
          {/* Profit zone background */}
          <rect
            x="0"
            y={profitZone.y}
            width="100"
            height={profitZone.height}
            className="fill-green-100 dark:fill-green-900/30"
          />

          {/* Grid lines */}
          <line
            x1="0"
            y1="25"
            x2="100"
            y2="25"
            className="stroke-gray-200 dark:stroke-gray-700"
            strokeWidth="0.5"
          />
          <line
            x1="0"
            y1="50"
            x2="100"
            y2="50"
            className="stroke-gray-200 dark:stroke-gray-700"
            strokeWidth="0.5"
          />
          <line
            x1="0"
            y1="75"
            x2="100"
            y2="75"
            className="stroke-gray-200 dark:stroke-gray-700"
            strokeWidth="0.5"
          />

          {/* Fixed rate line (dashed) */}
          <line
            x1="0"
            y1={fixedY}
            x2="100"
            y2={fixedY}
            className="stroke-purple-500"
            strokeWidth="1.5"
            strokeDasharray="4 2"
          />

          {/* Floating rate line */}
          <path
            d={floatingPath}
            fill="none"
            className="stroke-indigo-500"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Current rate point */}
          <circle
            cx="100"
            cy={rateToY(currentFloatingRate)}
            r="3"
            className="fill-indigo-500"
          />
        </svg>

        {/* Y-axis labels */}
        <div className="absolute left-2 top-1 text-xs text-gray-500 dark:text-gray-400">
          {maxRate.toFixed(1)}%
        </div>
        <div className="absolute left-2 bottom-1 text-xs text-gray-500 dark:text-gray-400">
          {minRate.toFixed(1)}%
        </div>

        {/* Fixed rate label */}
        <div
          className="absolute right-2 text-xs text-purple-600 dark:text-purple-400 font-medium"
          style={{ top: `${(fixedY / 100) * 100}%`, transform: "translateY(-50%)" }}
        >
          Fixed: {fixedRate.toFixed(2)}%
        </div>
      </div>

      {/* Legend */}
      <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400">
        <span>12 months ago</span>
        <span className="text-green-600 dark:text-green-400 font-medium">
          Profit Zone ({isPayingFixed ? "Above Fixed" : "Below Fixed"})
        </span>
        <span>Now</span>
      </div>
    </div>
  );
}
