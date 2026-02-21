"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { useReadContract, usePublicClient } from "wagmi";
import { formatUnits } from "viem";
import {
  Wallet,
  TrendingUp,
  TrendingDown,
  Shield,
  AlertTriangle,
  ChevronRight,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import {
  formatUSD,
  formatRate,
  formatNumber,
  getHealthColor,
  getHealthBgColor,
  cn,
} from "@/lib/utils";
import { POSITION_MANAGER_ABI, MARGIN_ENGINE_ABI, SETTLEMENT_ENGINE_ABI } from "@/lib/abis";

interface PortfolioSummaryProps {
  contracts: {
    positionManager: `0x${string}`;
    marginEngine: `0x${string}`;
    settlementEngine: `0x${string}`;
  };
  userAddress?: `0x${string}`;
}

interface PortfolioStats {
  totalMargin: number;
  totalNotional: number;
  totalPnL: number;
  pnlPercent: number;
  avgHealthFactor: number;
  positionCount: number;
  payingFixed: number;
  receivingFixed: number;
  isLoading: boolean;
}

export function PortfolioSummary({ contracts, userAddress }: PortfolioSummaryProps) {
  const [portfolioStats, setPortfolioStats] = useState<PortfolioStats>({
    totalMargin: 0,
    totalNotional: 0,
    totalPnL: 0,
    pnlPercent: 0,
    avgHealthFactor: 0,
    positionCount: 0,
    payingFixed: 0,
    receivingFixed: 0,
    isLoading: true,
  });

  const publicClient = usePublicClient();

  // Get next position ID to know how many positions exist
  const { data: nextPositionId } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "nextPositionId",
  });

  const fetchPortfolioData = useCallback(async () => {
    if (!nextPositionId || !publicClient || !userAddress) {
      setPortfolioStats(prev => ({ ...prev, isLoading: false }));
      return;
    }

    try {
      const positionCount = Number(nextPositionId);
      if (positionCount === 0) {
        setPortfolioStats(prev => ({ ...prev, isLoading: false }));
        return;
      }

      // Batch fetch all positions
      const positionCalls = [];
      for (let i = 0; i < positionCount; i++) {
        positionCalls.push({
          address: contracts.positionManager,
          abi: POSITION_MANAGER_ABI,
          functionName: "positions",
          args: [BigInt(i)],
        });
      }

      const positionsData = await publicClient.multicall({
        contracts: positionCalls as any,
        allowFailure: true,
      });

      // Filter user's active positions
      const userPositionIds: bigint[] = [];
      const userPositions: {
        id: bigint;
        isPayingFixed: boolean;
        notional: bigint;
        margin: bigint;
        accumulatedPnL: bigint;
      }[] = [];

      for (let i = 0; i < positionsData.length; i++) {
        const result = positionsData[i];
        if (result.status === "success" && result.result) {
          // ABI order: trader, isPayingFixed, startTime, maturity, isActive, notional, margin, fixedRate, accumulatedPnL, lastSettlement, _reserved
          const [trader, isPayingFixed, startTime, maturity, isActive, notional, margin, fixedRate, accumulatedPnL] = result.result as [
            string, boolean, bigint, bigint, boolean, bigint, bigint, bigint, bigint
          ];

          if (trader.toLowerCase() === userAddress.toLowerCase() && isActive) {
            userPositionIds.push(BigInt(i));
            userPositions.push({
              id: BigInt(i),
              isPayingFixed,
              notional,
              margin,
              accumulatedPnL,
            });
          }
        }
      }

      if (userPositions.length === 0) {
        setPortfolioStats({
          totalMargin: 0,
          totalNotional: 0,
          totalPnL: 0,
          pnlPercent: 0,
          avgHealthFactor: 0,
          positionCount: 0,
          payingFixed: 0,
          receivingFixed: 0,
          isLoading: false,
        });
        return;
      }

      // Fetch pending PnL and health factors for user's positions
      const additionalCalls = userPositionIds.flatMap((id) => [
        {
          address: contracts.settlementEngine,
          abi: SETTLEMENT_ENGINE_ABI,
          functionName: "getPendingSettlement",
          args: [id],
        },
        {
          address: contracts.marginEngine,
          abi: MARGIN_ENGINE_ABI,
          functionName: "getHealthFactor",
          args: [id],
        },
      ]);

      const additionalData = await publicClient.multicall({
        contracts: additionalCalls as any,
        allowFailure: true,
      });

      // Calculate portfolio stats
      let totalMargin = 0n;
      let totalNotional = 0n;
      let totalPnL = 0n;
      let totalHealthFactor = 0n;
      let healthFactorCount = 0;
      let payingFixed = 0;
      let receivingFixed = 0;

      for (let i = 0; i < userPositions.length; i++) {
        const position = userPositions[i];
        totalMargin += position.margin;
        totalNotional += position.notional;
        totalPnL += position.accumulatedPnL;

        if (position.isPayingFixed) {
          payingFixed++;
        } else {
          receivingFixed++;
        }

        // Get pending PnL (index i*2)
        const pendingPnLResult = additionalData[i * 2];
        if (pendingPnLResult.status === "success" && pendingPnLResult.result) {
          totalPnL += pendingPnLResult.result as bigint;
        }

        // Get health factor (index i*2 + 1)
        const healthResult = additionalData[i * 2 + 1];
        if (healthResult.status === "success" && healthResult.result) {
          totalHealthFactor += healthResult.result as bigint;
          healthFactorCount++;
        }
      }

      const totalMarginNum = Number(formatUnits(totalMargin, 6));
      const totalNotionalNum = Number(formatUnits(totalNotional, 6));
      const totalPnLNum = Number(formatUnits(totalPnL, 6));
      const avgHealthFactor = healthFactorCount > 0
        ? Number(formatUnits(totalHealthFactor / BigInt(healthFactorCount), 18))
        : 0;

      setPortfolioStats({
        totalMargin: totalMarginNum,
        totalNotional: totalNotionalNum,
        totalPnL: totalPnLNum,
        pnlPercent: totalMarginNum > 0 ? (totalPnLNum / totalMarginNum) * 100 : 0,
        avgHealthFactor,
        positionCount: userPositions.length,
        payingFixed,
        receivingFixed,
        isLoading: false,
      });
    } catch (error) {
      console.error("Error fetching portfolio data:", error);
      setPortfolioStats(prev => ({ ...prev, isLoading: false }));
    }
  }, [nextPositionId, publicClient, contracts, userAddress]);

  useEffect(() => {
    fetchPortfolioData();
  }, [fetchPortfolioData]);

  const isProfit = portfolioStats.totalPnL >= 0;

  return (
    <Card variant="glass" className="h-full">
      <CardHeader>
        <CardTitle icon={<Wallet className="w-5 h-5" />}>
          Your Portfolio
        </CardTitle>
      </CardHeader>

      <CardContent className="space-y-6">
        {!userAddress ? (
          <div className="text-center py-8">
            <Wallet className="w-12 h-12 mx-auto text-slate-600 mb-4" />
            <p className="text-slate-400">Connect wallet to view portfolio</p>
          </div>
        ) : portfolioStats.isLoading ? (
          <div className="text-center py-8">
            <motion.div
              className="w-8 h-8 border-2 border-neon-cyan border-t-transparent rounded-full mx-auto mb-4"
              animate={{ rotate: 360 }}
              transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
            />
            <p className="text-slate-400">Loading portfolio...</p>
          </div>
        ) : portfolioStats.positionCount === 0 ? (
          <div className="text-center py-8">
            <Wallet className="w-12 h-12 mx-auto text-slate-600 mb-4" />
            <p className="text-slate-400">No active positions</p>
            <p className="text-sm text-slate-500 mt-2">Open a position to get started</p>
          </div>
        ) : (
          <>
            {/* Total Value */}
            <div className="text-center pb-6 border-b border-white/5">
              <div className="text-sm text-slate-400 mb-2">Total Margin Locked</div>
              <div className="text-3xl font-bold font-display mb-2">
                {formatUSD(portfolioStats.totalMargin)}
              </div>
              <div
                className={cn(
                  "inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium",
                  isProfit
                    ? "bg-neon-green/10 text-neon-green"
                    : "bg-red-500/10 text-red-400"
                )}
              >
                {isProfit ? (
                  <TrendingUp className="w-4 h-4" />
                ) : (
                  <TrendingDown className="w-4 h-4" />
                )}
                {isProfit ? "+" : ""}
                {formatUSD(portfolioStats.totalPnL)} ({portfolioStats.pnlPercent.toFixed(2)}%)
              </div>
            </div>

            {/* Position Breakdown */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-400">Active Positions</span>
                <span className="font-semibold">{portfolioStats.positionCount}</span>
              </div>

              {/* Position Type Distribution */}
              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full bg-neon-cyan" />
                    <span className="text-slate-400">Paying Fixed</span>
                  </div>
                  <span>{portfolioStats.payingFixed}</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full bg-neon-purple" />
                    <span className="text-slate-400">Receiving Fixed</span>
                  </div>
                  <span>{portfolioStats.receivingFixed}</span>
                </div>

                {/* Visual Bar */}
                {(portfolioStats.payingFixed + portfolioStats.receivingFixed) > 0 && (
                  <div className="h-2 rounded-full bg-dark-800 overflow-hidden flex">
                    <motion.div
                      className="h-full bg-gradient-to-r from-neon-cyan to-cyan-400"
                      initial={{ width: 0 }}
                      animate={{
                        width: `${(portfolioStats.payingFixed / (portfolioStats.payingFixed + portfolioStats.receivingFixed)) * 100}%`,
                      }}
                      transition={{ duration: 0.5 }}
                    />
                    <motion.div
                      className="h-full bg-gradient-to-r from-neon-purple to-purple-400"
                      initial={{ width: 0 }}
                      animate={{
                        width: `${(portfolioStats.receivingFixed / (portfolioStats.payingFixed + portfolioStats.receivingFixed)) * 100}%`,
                      }}
                      transition={{ duration: 0.5 }}
                    />
                  </div>
                )}
              </div>
            </div>

            {/* Health Factor */}
            <div className="p-4 rounded-xl bg-dark-800/50 border border-white/5">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-slate-400" />
                  <span className="text-sm text-slate-400">Avg Health Factor</span>
                </div>
                <span
                  className={cn(
                    "text-lg font-bold",
                    getHealthColor(portfolioStats.avgHealthFactor)
                  )}
                >
                  {portfolioStats.avgHealthFactor.toFixed(2)}
                </span>
              </div>

              {/* Health Bar */}
              <div className="relative h-2 rounded-full bg-dark-700 overflow-hidden">
                <motion.div
                  className={cn(
                    "absolute inset-y-0 left-0 rounded-full",
                    portfolioStats.avgHealthFactor >= 2
                      ? "bg-neon-green"
                      : portfolioStats.avgHealthFactor >= 1.5
                      ? "bg-green-400"
                      : portfolioStats.avgHealthFactor >= 1.2
                      ? "bg-yellow-400"
                      : "bg-red-500"
                  )}
                  initial={{ width: 0 }}
                  animate={{
                    width: `${Math.min((portfolioStats.avgHealthFactor / 3) * 100, 100)}%`,
                  }}
                  transition={{ duration: 0.5, delay: 0.2 }}
                />
                {/* Threshold markers */}
                <div className="absolute top-0 bottom-0 left-1/3 w-px bg-white/20" />
                <div className="absolute top-0 bottom-0 left-2/3 w-px bg-white/20" />
              </div>

              <div className="flex justify-between mt-1 text-xs text-slate-600">
                <span>Liquidation</span>
                <span>Safe</span>
                <span>Optimal</span>
              </div>
            </div>

            {/* Notional Exposure */}
            <div className="flex items-center justify-between p-4 rounded-xl bg-dark-800/50 border border-white/5">
              <div>
                <div className="text-sm text-slate-400 mb-1">Total Notional</div>
                <div className="text-xl font-bold">{formatUSD(portfolioStats.totalNotional)}</div>
              </div>
              <div className="text-right">
                <div className="text-sm text-slate-400 mb-1">Leverage</div>
                <div className="text-xl font-bold">
                  {portfolioStats.totalMargin > 0
                    ? (portfolioStats.totalNotional / portfolioStats.totalMargin).toFixed(1)
                    : "0.0"}x
                </div>
              </div>
            </div>

            {/* CTA */}
            <motion.button
              className="w-full p-4 rounded-xl bg-gradient-to-r from-neon-cyan/20 to-neon-purple/20 border border-neon-cyan/30 flex items-center justify-between group hover:border-neon-cyan/50 transition-colors"
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
            >
              <span className="font-medium">View All Positions</span>
              <ChevronRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
            </motion.button>
          </>
        )}
      </CardContent>
    </Card>
  );
}
