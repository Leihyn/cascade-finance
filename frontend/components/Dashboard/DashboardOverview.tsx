"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { useReadContract, useAccount } from "wagmi";
import {
  TrendingUp,
  TrendingDown,
  Activity,
  DollarSign,
  Shield,
  ArrowUpRight,
  ArrowDownRight,
  LayoutDashboard,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { StatCardSkeleton, ChartSkeleton, PositionSkeleton } from "@/components/ui/Skeleton";
import { formatUSD, formatRate, formatNumber, cn } from "@/lib/utils";
import { RATE_ORACLE_ABI, POSITION_MANAGER_ABI } from "@/lib/abis";
import { PortfolioSummary } from "./PortfolioSummary";
import { RateChart } from "./RateChart";
import { PositionBreakdown } from "./PositionBreakdown";

interface DashboardOverviewProps {
  contracts: {
    positionManager: `0x${string}`;
    rateOracle: `0x${string}`;
    marginEngine: `0x${string}`;
    settlementEngine: `0x${string}`;
  };
}

export function DashboardOverview({ contracts }: DashboardOverviewProps) {
  const { address } = useAccount();
  const [animatedTVL, setAnimatedTVL] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  // Fetch protocol stats
  const { data: currentRate, isLoading: rateLoading } = useReadContract({
    address: contracts.rateOracle,
    abi: RATE_ORACLE_ABI,
    functionName: "getCurrentRate",
  });

  const { data: totalMargin, isLoading: marginLoading } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "totalMargin",
  });

  const { data: activePositions, isLoading: positionsLoading } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "activePositionCount",
  });

  // Simulate loading
  useEffect(() => {
    const timer = setTimeout(() => setIsLoading(false), 1500);
    return () => clearTimeout(timer);
  }, []);

  // Animate TVL counter
  useEffect(() => {
    if (totalMargin) {
      const target = Number(totalMargin) / 1e6;
      const duration = 1000;
      const steps = 60;
      const increment = target / steps;
      let current = 0;

      const timer = setInterval(() => {
        current += increment;
        if (current >= target) {
          setAnimatedTVL(target);
          clearInterval(timer);
        } else {
          setAnimatedTVL(current);
        }
      }, duration / steps);

      return () => clearInterval(timer);
    }
  }, [totalMargin]);

  const stats = [
    {
      label: "Total Value Locked",
      value: formatUSD(animatedTVL || 125000),
      change: "+12.5%",
      changeType: "positive" as const,
      icon: <DollarSign className="w-5 h-5" />,
      color: "from-neon-cyan to-neon-blue",
    },
    {
      label: "Current Floating Rate",
      value: currentRate ? formatRate(currentRate as bigint) : "5.23%",
      change: "+0.8%",
      changeType: "positive" as const,
      icon: <TrendingUp className="w-5 h-5" />,
      color: "from-neon-purple to-neon-pink",
    },
    {
      label: "Active Positions",
      value: activePositions ? formatNumber(Number(activePositions), { decimals: 0 }) : "247",
      change: "+23",
      changeType: "positive" as const,
      icon: <Activity className="w-5 h-5" />,
      color: "from-neon-green to-neon-cyan",
    },
    {
      label: "Protocol Health",
      value: "98.5%",
      change: "Optimal",
      changeType: "neutral" as const,
      icon: <Shield className="w-5 h-5" />,
      color: "from-green-400 to-emerald-500",
    },
  ];

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <StatCardSkeleton key={i} />
          ))}
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <ChartSkeleton />
          </div>
          <div>
            <ChartSkeleton />
          </div>
        </div>
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <PositionSkeleton key={i} />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-neon-cyan to-neon-purple flex items-center justify-center">
            <LayoutDashboard className="w-5 h-5 text-dark-950" />
          </div>
          <div>
            <h2 className="text-xl font-bold font-display">Dashboard</h2>
            <p className="text-sm text-slate-400">Your IRS Protocol overview</p>
          </div>
        </div>
      </motion.div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat, index) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
          >
            <Card variant="glass" className="relative overflow-hidden">
              {/* Gradient accent */}
              <div
                className={cn(
                  "absolute top-0 right-0 w-32 h-32 rounded-full blur-3xl opacity-20",
                  `bg-gradient-to-br ${stat.color}`
                )}
              />

              <div className="relative">
                <div className="flex items-center justify-between mb-3">
                  <div
                    className={cn(
                      "w-10 h-10 rounded-xl flex items-center justify-center",
                      `bg-gradient-to-br ${stat.color}`
                    )}
                  >
                    <span className="text-dark-950">{stat.icon}</span>
                  </div>
                  {stat.changeType !== "neutral" && (
                    <div
                      className={cn(
                        "flex items-center gap-1 text-xs font-medium px-2 py-1 rounded-full",
                        stat.changeType === "positive"
                          ? "text-neon-green bg-neon-green/10"
                          : "text-red-400 bg-red-400/10"
                      )}
                    >
                      {stat.changeType === "positive" ? (
                        <ArrowUpRight className="w-3 h-3" />
                      ) : (
                        <ArrowDownRight className="w-3 h-3" />
                      )}
                      {stat.change}
                    </div>
                  )}
                  {stat.changeType === "neutral" && (
                    <div className="text-xs text-neon-green bg-neon-green/10 px-2 py-1 rounded-full">
                      {stat.change}
                    </div>
                  )}
                </div>

                <div className="text-2xl font-bold font-display mb-1">
                  {stat.value}
                </div>
                <div className="text-sm text-slate-400">{stat.label}</div>
              </div>
            </Card>
          </motion.div>
        ))}
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Rate Chart - 2 columns */}
        <div className="lg:col-span-2">
          <RateChart contracts={contracts} />
        </div>

        {/* Portfolio Summary - 1 column */}
        <div>
          <PortfolioSummary contracts={contracts} userAddress={address} />
        </div>
      </div>

      {/* Position Breakdown */}
      {address && (
        <PositionBreakdown contracts={contracts} userAddress={address} />
      )}
    </div>
  );
}
