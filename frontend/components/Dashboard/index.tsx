"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { useReadContract, useReadContracts, useAccount } from "wagmi";
import {
  TrendingUp,
  TrendingDown,
  Activity,
  DollarSign,
  BarChart3,
  PieChart,
  Wallet,
  Shield,
  Clock,
  Zap,
  ArrowUpRight,
  ArrowDownRight,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { formatUSD, formatRate, formatNumber, cn } from "@/lib/utils";
import { RATE_ORACLE_ABI, POSITION_MANAGER_ABI, MARGIN_ENGINE_ABI } from "@/lib/abis";
import { PortfolioSummary } from "./PortfolioSummary";
import { RateChart } from "./RateChart";
import { PositionBreakdown } from "./PositionBreakdown";

interface DashboardProps {
  contracts: {
    positionManager: `0x${string}`;
    rateOracle: `0x${string}`;
    marginEngine: `0x${string}`;
    settlementEngine: `0x${string}`;
  };
}

export function Dashboard({ contracts }: DashboardProps) {
  const { address } = useAccount();
  const [animatedTVL, setAnimatedTVL] = useState(0);

  // Fetch protocol stats
  const { data: currentRate } = useReadContract({
    address: contracts.rateOracle,
    abi: RATE_ORACLE_ABI,
    functionName: "getCurrentRate",
  });

  const { data: totalMargin } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "totalMargin",
  });

  const { data: activePositions } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "activePositionCount",
  });

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
      value: formatUSD(animatedTVL),
      change: "+12.5%",
      changeType: "positive" as const,
      icon: <DollarSign className="w-5 h-5" />,
      color: "from-neon-cyan to-neon-blue",
    },
    {
      label: "Current Floating Rate",
      value: currentRate ? formatRate(currentRate as bigint) : "...",
      change: currentRate ? "+0.8%" : "",
      changeType: "positive" as const,
      icon: <TrendingUp className="w-5 h-5" />,
      color: "from-neon-purple to-neon-pink",
    },
    {
      label: "Active Positions",
      value: activePositions ? formatNumber(Number(activePositions), { decimals: 0 }) : "...",
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

  return (
    <div className="space-y-6">
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

      {/* Quick Actions */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <motion.button
          className="glass-card p-4 flex items-center gap-4 hover:border-neon-cyan/50 transition-colors group"
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
        >
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-neon-cyan to-neon-blue flex items-center justify-center group-hover:scale-110 transition-transform">
            <TrendingUp className="w-6 h-6 text-dark-950" />
          </div>
          <div className="text-left">
            <div className="font-semibold">Open Position</div>
            <div className="text-sm text-slate-400">Trade interest rates</div>
          </div>
        </motion.button>

        <motion.button
          className="glass-card p-4 flex items-center gap-4 hover:border-neon-purple/50 transition-colors group"
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
        >
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-neon-purple to-neon-pink flex items-center justify-center group-hover:scale-110 transition-transform">
            <Wallet className="w-6 h-6 text-dark-950" />
          </div>
          <div className="text-left">
            <div className="font-semibold">Supply Liquidity</div>
            <div className="text-sm text-slate-400">Earn yield on USDC</div>
          </div>
        </motion.button>

        <motion.button
          className="glass-card p-4 flex items-center gap-4 hover:border-neon-green/50 transition-colors group"
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
        >
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-neon-green to-emerald-500 flex items-center justify-center group-hover:scale-110 transition-transform">
            <Zap className="w-6 h-6 text-dark-950" />
          </div>
          <div className="text-left">
            <div className="font-semibold">Swap Tokens</div>
            <div className="text-sm text-slate-400">Trade instantly</div>
          </div>
        </motion.button>
      </div>
    </div>
  );
}

// Re-export the new DashboardOverview component
export { DashboardOverview } from "./DashboardOverview";
