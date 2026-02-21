"use client";

import { useState, useEffect, useMemo } from "react";
import { motion } from "framer-motion";
import { useReadContract } from "wagmi";
import { TrendingUp, Clock, ChevronDown } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { formatRate, cn } from "@/lib/utils";
import { RATE_ORACLE_ABI } from "@/lib/abis";

interface RateChartProps {
  contracts: {
    rateOracle: `0x${string}`;
  };
}

type TimeRange = "1H" | "24H" | "7D" | "30D";

// Generate mock historical data for visualization
function generateMockRateHistory(currentRate: number, points: number, volatility: number): number[] {
  const history: number[] = [];
  let rate = currentRate * (0.8 + Math.random() * 0.2);

  for (let i = 0; i < points; i++) {
    const change = (Math.random() - 0.5) * volatility;
    rate = Math.max(0.01, rate + change);
    history.push(rate);
  }

  // Ensure last point is close to current rate
  history[history.length - 1] = currentRate;
  return history;
}

export function RateChart({ contracts }: RateChartProps) {
  const [timeRange, setTimeRange] = useState<TimeRange>("24H");
  const [hoveredPoint, setHoveredPoint] = useState<number | null>(null);

  const { data: currentRate } = useReadContract({
    address: contracts.rateOracle,
    abi: RATE_ORACLE_ABI,
    functionName: "getCurrentRate",
  });

  const currentRateNum = currentRate ? Number(currentRate) / 1e18 : 0.05;

  // Generate chart data based on time range
  const chartData = useMemo(() => {
    const points = timeRange === "1H" ? 60 : timeRange === "24H" ? 96 : timeRange === "7D" ? 168 : 720;
    const volatility = timeRange === "1H" ? 0.001 : timeRange === "24H" ? 0.003 : timeRange === "7D" ? 0.008 : 0.015;
    return generateMockRateHistory(currentRateNum, points, volatility);
  }, [currentRateNum, timeRange]);

  const minRate = Math.min(...chartData);
  const maxRate = Math.max(...chartData);
  const range = maxRate - minRate || 0.01;

  // Calculate if rate is up or down
  const startRate = chartData[0];
  const endRate = chartData[chartData.length - 1];
  const isUp = endRate >= startRate;
  const changePercent = ((endRate - startRate) / startRate) * 100;

  // Generate SVG path
  const width = 100;
  const height = 40;
  const points = chartData.map((rate, i) => {
    const x = (i / (chartData.length - 1)) * width;
    const y = height - ((rate - minRate) / range) * height;
    return `${x},${y}`;
  });
  const linePath = `M ${points.join(" L ")}`;
  const areaPath = `${linePath} L ${width},${height} L 0,${height} Z`;

  const timeRanges: TimeRange[] = ["1H", "24H", "7D", "30D"];

  return (
    <Card variant="glass" className="h-full">
      <CardHeader>
        <CardTitle icon={<TrendingUp className="w-5 h-5" />}>
          Interest Rate History
        </CardTitle>
        <div className="flex items-center gap-2">
          {timeRanges.map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={cn(
                "px-3 py-1.5 rounded-lg text-sm font-medium transition-all",
                timeRange === range
                  ? "bg-neon-cyan/20 text-neon-cyan border border-neon-cyan/30"
                  : "text-slate-400 hover:text-white hover:bg-white/5"
              )}
            >
              {range}
            </button>
          ))}
        </div>
      </CardHeader>

      <CardContent>
        {/* Current Rate Display */}
        <div className="flex items-end justify-between mb-6">
          <div>
            <div className="text-4xl font-bold font-display">
              {(currentRateNum * 100).toFixed(2)}%
            </div>
            <div className="text-sm text-slate-400 mt-1">Current Floating Rate</div>
          </div>
          <div
            className={cn(
              "flex items-center gap-1 px-3 py-1.5 rounded-full text-sm font-medium",
              isUp
                ? "bg-neon-green/10 text-neon-green"
                : "bg-red-500/10 text-red-400"
            )}
          >
            {isUp ? (
              <TrendingUp className="w-4 h-4" />
            ) : (
              <TrendingUp className="w-4 h-4 rotate-180" />
            )}
            {changePercent >= 0 ? "+" : ""}
            {changePercent.toFixed(2)}%
          </div>
        </div>

        {/* Chart Container */}
        <div
          className="relative h-48 group"
          onMouseLeave={() => setHoveredPoint(null)}
        >
          {/* Grid Lines */}
          <div className="absolute inset-0 flex flex-col justify-between pointer-events-none">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="flex items-center gap-2">
                <span className="text-xs text-slate-600 w-12">
                  {((maxRate - (range * i / 3)) * 100).toFixed(1)}%
                </span>
                <div className="flex-1 border-t border-white/5" />
              </div>
            ))}
          </div>

          {/* SVG Chart */}
          <svg
            viewBox={`0 0 ${width} ${height}`}
            className="absolute inset-0 w-full h-full pl-14"
            preserveAspectRatio="none"
          >
            {/* Gradient Definition */}
            <defs>
              <linearGradient id="rateGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor={isUp ? "#00ffcc" : "#ef4444"} stopOpacity="0.3" />
                <stop offset="100%" stopColor={isUp ? "#00ffcc" : "#ef4444"} stopOpacity="0" />
              </linearGradient>
              <linearGradient id="lineGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor={isUp ? "#00ffcc" : "#ef4444"} stopOpacity="0.5" />
                <stop offset="100%" stopColor={isUp ? "#00ffcc" : "#ef4444"} stopOpacity="1" />
              </linearGradient>
            </defs>

            {/* Area Fill */}
            <motion.path
              d={areaPath}
              fill="url(#rateGradient)"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.5 }}
            />

            {/* Line */}
            <motion.path
              d={linePath}
              fill="none"
              stroke="url(#lineGradient)"
              strokeWidth="0.5"
              strokeLinecap="round"
              initial={{ pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 1, ease: "easeOut" }}
            />

            {/* Animated Dot at End */}
            <motion.circle
              cx={width}
              cy={height - ((endRate - minRate) / range) * height}
              r="1.5"
              fill={isUp ? "#00ffcc" : "#ef4444"}
              initial={{ scale: 0 }}
              animate={{ scale: [1, 1.5, 1] }}
              transition={{ duration: 2, repeat: Infinity }}
            />
          </svg>

          {/* Hover Interaction Layer */}
          <div
            className="absolute inset-0 pl-14 flex"
            onMouseMove={(e) => {
              const rect = e.currentTarget.getBoundingClientRect();
              const x = (e.clientX - rect.left) / rect.width;
              const index = Math.floor(x * chartData.length);
              setHoveredPoint(Math.min(index, chartData.length - 1));
            }}
          >
            {hoveredPoint !== null && (
              <motion.div
                className="absolute top-0 bottom-0 w-px bg-white/30"
                style={{ left: `${(hoveredPoint / chartData.length) * 100}%` }}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
              />
            )}
          </div>

          {/* Tooltip */}
          {hoveredPoint !== null && (
            <motion.div
              className="absolute top-2 left-16 glass-card px-3 py-2 text-sm"
              initial={{ opacity: 0, y: 5 }}
              animate={{ opacity: 1, y: 0 }}
            >
              <div className="font-semibold">{(chartData[hoveredPoint] * 100).toFixed(3)}%</div>
              <div className="text-xs text-slate-400">
                {timeRange === "1H" && `${hoveredPoint} min ago`}
                {timeRange === "24H" && `${Math.floor(hoveredPoint * 15)} min ago`}
                {timeRange === "7D" && `${Math.floor(hoveredPoint)} hours ago`}
                {timeRange === "30D" && `${Math.floor(hoveredPoint / 24)} days ago`}
              </div>
            </motion.div>
          )}
        </div>

        {/* Time Labels */}
        <div className="flex justify-between mt-2 pl-14 text-xs text-slate-500">
          <span>{timeRange === "1H" ? "60 min ago" : timeRange === "24H" ? "24h ago" : timeRange === "7D" ? "7d ago" : "30d ago"}</span>
          <span>Now</span>
        </div>

        {/* Data Source Note */}
        <div className="mt-2 text-xs text-slate-600 text-center">
          Current rate is live • Historical data is simulated
        </div>

        {/* Stats Row */}
        <div className="grid grid-cols-3 gap-4 mt-6 pt-6 border-t border-white/5">
          <div>
            <div className="text-xs text-slate-500 mb-1">High</div>
            <div className="font-semibold text-neon-green">{(maxRate * 100).toFixed(2)}%</div>
          </div>
          <div>
            <div className="text-xs text-slate-500 mb-1">Low</div>
            <div className="font-semibold text-red-400">{(minRate * 100).toFixed(2)}%</div>
          </div>
          <div>
            <div className="text-xs text-slate-500 mb-1">Average</div>
            <div className="font-semibold">
              {((chartData.reduce((a, b) => a + b, 0) / chartData.length) * 100).toFixed(2)}%
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
