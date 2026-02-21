"use client";

import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { usePublicClient, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits } from "viem";
import {
  BarChart3,
  TrendingUp,
  TrendingDown,
  Clock,
  Shield,
  ChevronDown,
  Zap,
  AlertTriangle,
  RefreshCw,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/Card";
import { PositionSkeleton } from "@/components/ui/Skeleton";
import { POSITION_MANAGER_ABI, SETTLEMENT_ENGINE_ABI, MARGIN_ENGINE_ABI } from "@/lib/abis";
import {
  formatUSD,
  formatTimeRemaining,
  getHealthColor,
  cn,
} from "@/lib/utils";

interface Position {
  id: bigint;
  trader: string;
  isPayingFixed: boolean;
  startTime: number;
  maturity: number;
  isActive: boolean;
  notional: bigint;
  margin: bigint;
  fixedRate: bigint;
  accumulatedPnL: bigint;
  lastSettlement: number;
  pendingPnL: bigint;
  canSettle: boolean;
  healthFactor: number;
}

interface PositionBreakdownProps {
  contracts: {
    positionManager: `0x${string}`;
    marginEngine: `0x${string}`;
    settlementEngine: `0x${string}`;
  };
  userAddress: `0x${string}`;
}

export function PositionBreakdown({ contracts, userAddress }: PositionBreakdownProps) {
  const [positions, setPositions] = useState<Position[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedPosition, setExpandedPosition] = useState<bigint | null>(null);
  const [sortBy, setSortBy] = useState<"pnl" | "maturity" | "health">("pnl");
  const publicClient = usePublicClient();

  // Get next position ID
  const { data: nextPositionId, refetch: refetchNextId } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "nextPositionId",
  });

  const { writeContract, isPending, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  const fetchPositions = useCallback(async () => {
    if (!publicClient || !userAddress) return;

    if (!nextPositionId || nextPositionId === BigInt(0)) {
      setPositions([]);
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      // Build array of position IDs
      const positionIds = Array.from(
        { length: Number(nextPositionId) },
        (_, i) => BigInt(i)
      );

      // Batch fetch all positions
      const positionCalls = positionIds.map((id) => ({
        address: contracts.positionManager,
        abi: POSITION_MANAGER_ABI,
        functionName: "positions" as const,
        args: [id] as const,
      }));

      const positionsData = await publicClient.multicall({
        contracts: positionCalls,
        allowFailure: true,
      });

      // Parse and filter user's active positions
      const userPositions: Position[] = [];
      const activePositionIds: bigint[] = [];

      for (let i = 0; i < positionsData.length; i++) {
        const result = positionsData[i];
        if (result.status === "failure") continue;

        const data = result.result as [string, boolean, number, number, boolean, bigint, bigint, bigint, bigint, number, bigint];
        const [trader, isPayingFixed, startTime, maturity, isActive, notional, margin, fixedRate, accumulatedPnL, lastSettlement] = data;

        // Debug logging
        console.log(`Position ${i}:`, {
          trader,
          isPayingFixed,
          isActive,
          notional: notional.toString(),
          margin: margin.toString(),
          accumulatedPnL: accumulatedPnL.toString(),
          userAddress,
        });

        // Only include user's active positions
        if (trader.toLowerCase() === userAddress.toLowerCase() && isActive) {
          userPositions.push({
            id: BigInt(i),
            trader,
            isPayingFixed,
            startTime: Number(startTime),
            maturity: Number(maturity),
            isActive,
            notional,
            margin,
            fixedRate,
            accumulatedPnL,
            lastSettlement: Number(lastSettlement),
            pendingPnL: BigInt(0),
            canSettle: false,
            healthFactor: 2.0, // Default, will be updated
          });
          activePositionIds.push(BigInt(i));
        }
      }

      // Fetch settlement and health data for user's positions
      if (activePositionIds.length > 0) {
        const additionalCalls = activePositionIds.flatMap((id) => [
          {
            address: contracts.settlementEngine,
            abi: SETTLEMENT_ENGINE_ABI,
            functionName: "getPendingSettlement" as const,
            args: [id] as const,
          },
          {
            address: contracts.settlementEngine,
            abi: SETTLEMENT_ENGINE_ABI,
            functionName: "canSettle" as const,
            args: [id] as const,
          },
          {
            address: contracts.marginEngine,
            abi: MARGIN_ENGINE_ABI,
            functionName: "getHealthFactor" as const,
            args: [id] as const,
          },
        ]);

        const additionalData = await publicClient.multicall({
          contracts: additionalCalls,
          allowFailure: true,
        });

        for (let i = 0; i < activePositionIds.length; i++) {
          const positionId = activePositionIds[i];
          const pendingResult = additionalData[i * 3];
          const canSettleResult = additionalData[i * 3 + 1];
          const healthResult = additionalData[i * 3 + 2];

          // Debug logging for additional data
          console.log(`Position ${positionId.toString()} additional data:`, {
            pendingResult: pendingResult.status === "success" ? (pendingResult.result as bigint).toString() : "failed",
            canSettleResult: canSettleResult.status === "success" ? canSettleResult.result : "failed",
            healthResult: healthResult.status === "success" ? (healthResult.result as bigint).toString() : "failed",
          });

          const position = userPositions.find((p) => p.id === positionId);
          if (position) {
            if (pendingResult.status === "success") {
              position.pendingPnL = pendingResult.result as bigint;
            }
            if (canSettleResult.status === "success") {
              position.canSettle = canSettleResult.result as boolean;
            }
            if (healthResult.status === "success") {
              const healthBigInt = healthResult.result as bigint;
              position.healthFactor = Number(formatUnits(healthBigInt, 18));
            }
          }
        }
      }

      setPositions(userPositions);
    } catch (e) {
      console.error("Error fetching positions:", e);
    } finally {
      setLoading(false);
    }
  }, [nextPositionId, publicClient, contracts, userAddress]);

  useEffect(() => {
    fetchPositions();
  }, [fetchPositions]);

  useEffect(() => {
    if (isConfirmed) {
      refetchNextId();
    }
  }, [isConfirmed, refetchNextId]);

  const handleSettle = (positionId: bigint) => {
    writeContract({
      address: contracts.settlementEngine,
      abi: SETTLEMENT_ENGINE_ABI,
      functionName: "settle",
      args: [positionId],
    });
  };

  const formatRate = (rate: bigint) => {
    return (Number(formatUnits(rate, 18)) * 100).toFixed(2) + "%";
  };

  const formatUSDC = (amount: bigint) => {
    return "$" + Number(formatUnits(amount, 6)).toLocaleString(undefined, { minimumFractionDigits: 2 });
  };

  const formatPnL = (pnl: bigint) => {
    const value = Number(formatUnits(pnl, 6));
    return value;
  };

  const getTotalPnL = (position: Position) => {
    const accumulated = Number(formatUnits(position.accumulatedPnL, 6));
    const pending = Number(formatUnits(position.pendingPnL, 6));
    return accumulated + pending;
  };

  // Sort positions
  const sortedPositions = [...positions].sort((a, b) => {
    if (sortBy === "pnl") return getTotalPnL(b) - getTotalPnL(a);
    if (sortBy === "maturity") return a.maturity - b.maturity;
    return a.healthFactor - b.healthFactor;
  });

  const isWorking = isPending || isConfirming;

  if (loading) {
    return (
      <Card variant="glass">
        <CardHeader>
          <CardTitle icon={<BarChart3 className="w-5 h-5" />}>
            Your Active Positions
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <PositionSkeleton key={i} />
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card variant="glass">
      <CardHeader>
        <CardTitle icon={<BarChart3 className="w-5 h-5" />}>
          Your Active Positions
        </CardTitle>
        <div className="flex items-center gap-3">
          <button
            onClick={() => refetchNextId()}
            className="p-2 rounded-lg hover:bg-white/5 transition-colors"
            title="Refresh"
          >
            <RefreshCw className="w-4 h-4 text-slate-400" />
          </button>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as any)}
            className="bg-dark-800 border border-white/10 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-neon-cyan/50"
          >
            <option value="pnl">Sort by PnL</option>
            <option value="maturity">Sort by Maturity</option>
            <option value="health">Sort by Health</option>
          </select>
        </div>
      </CardHeader>

      <CardContent>
        {sortedPositions.length === 0 ? (
          <div className="text-center py-12">
            <BarChart3 className="w-12 h-12 mx-auto text-slate-600 mb-4" />
            <p className="text-slate-400 mb-2">No active positions</p>
            <p className="text-sm text-slate-500">Open a position in the Interest Rate Swaps tab</p>
          </div>
        ) : (
          <div className="space-y-3">
            {sortedPositions.map((position, index) => {
              const totalPnL = getTotalPnL(position);
              const isExpanded = expandedPosition === position.id;

              return (
                <motion.div
                  key={position.id.toString()}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.05 }}
                  className={cn(
                    "rounded-xl border transition-all overflow-hidden",
                    isExpanded
                      ? "border-neon-cyan/50 bg-dark-800/50"
                      : "border-white/10 bg-dark-900/50 hover:border-white/20"
                  )}
                >
                  {/* Position Header */}
                  <button
                    onClick={() => setExpandedPosition(isExpanded ? null : position.id)}
                    className="w-full p-4 flex items-center justify-between"
                  >
                    <div className="flex items-center gap-4">
                      <div
                        className={cn(
                          "w-10 h-10 rounded-xl flex items-center justify-center",
                          position.isPayingFixed
                            ? "bg-neon-cyan/20 text-neon-cyan"
                            : "bg-neon-purple/20 text-neon-purple"
                        )}
                      >
                        {position.isPayingFixed ? (
                          <TrendingUp className="w-5 h-5" />
                        ) : (
                          <TrendingDown className="w-5 h-5" />
                        )}
                      </div>

                      <div className="text-left">
                        <div className="font-semibold flex items-center gap-2">
                          Position #{position.id.toString()}
                          {position.canSettle && (
                            <span className="px-2 py-0.5 rounded-full bg-neon-green/20 text-neon-green text-xs animate-pulse">
                              Settleable
                            </span>
                          )}
                        </div>
                        <div className="text-sm text-slate-400">
                          {position.isPayingFixed ? "Pay Fixed" : "Receive Fixed"} @ {formatRate(position.fixedRate)}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-6">
                      <div className="text-right">
                        <div
                          className={cn(
                            "font-bold",
                            totalPnL >= 0 ? "text-neon-green" : "text-red-400"
                          )}
                        >
                          {totalPnL >= 0 ? "+" : ""}{formatUSD(totalPnL)}
                        </div>
                        <div className="text-xs text-slate-500">Total PnL</div>
                      </div>

                      <div className="text-right hidden sm:block">
                        <div className={cn("font-bold", getHealthColor(position.healthFactor))}>
                          {position.healthFactor.toFixed(2)}
                        </div>
                        <div className="text-xs text-slate-500">Health</div>
                      </div>

                      <motion.div
                        animate={{ rotate: isExpanded ? 180 : 0 }}
                        transition={{ duration: 0.2 }}
                      >
                        <ChevronDown className="w-5 h-5 text-slate-400" />
                      </motion.div>
                    </div>
                  </button>

                  {/* Expanded Details */}
                  <AnimatePresence>
                    {isExpanded && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: "auto", opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.2 }}
                      >
                        <div className="px-4 pb-4 border-t border-white/5 pt-4">
                          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                            <div className="p-3 rounded-lg bg-dark-800/50">
                              <div className="text-xs text-slate-500 mb-1">Notional</div>
                              <div className="font-semibold">{formatUSDC(position.notional)}</div>
                            </div>
                            <div className="p-3 rounded-lg bg-dark-800/50">
                              <div className="text-xs text-slate-500 mb-1">Margin</div>
                              <div className="font-semibold">{formatUSDC(position.margin)}</div>
                            </div>
                            <div className="p-3 rounded-lg bg-dark-800/50">
                              <div className="text-xs text-slate-500 mb-1">Maturity</div>
                              <div className="font-semibold flex items-center gap-1">
                                <Clock className="w-3 h-3" />
                                {formatTimeRemaining(position.maturity - Math.floor(Date.now() / 1000))}
                              </div>
                            </div>
                            <div className="p-3 rounded-lg bg-dark-800/50">
                              <div className="text-xs text-slate-500 mb-1">Leverage</div>
                              <div className="font-semibold">
                                {(Number(formatUnits(position.notional, 6)) / Number(formatUnits(position.margin, 6))).toFixed(1)}x
                              </div>
                            </div>
                          </div>

                          {/* PnL Breakdown */}
                          <div className="mt-4 p-3 rounded-lg bg-dark-800/50">
                            <div className="flex justify-between items-center mb-2">
                              <span className="text-sm text-slate-400">Settled PnL</span>
                              <span className={cn("font-semibold", formatPnL(position.accumulatedPnL) >= 0 ? "text-neon-green" : "text-red-400")}>
                                {formatPnL(position.accumulatedPnL) >= 0 ? "+" : ""}{formatUSDC(position.accumulatedPnL)}
                              </span>
                            </div>
                            <div className="flex justify-between items-center">
                              <span className="text-sm text-slate-400">Pending Settlement</span>
                              <span className={cn("font-semibold", formatPnL(position.pendingPnL) >= 0 ? "text-neon-green" : "text-red-400")}>
                                {formatPnL(position.pendingPnL) >= 0 ? "+" : ""}{formatUSDC(position.pendingPnL)}
                              </span>
                            </div>
                          </div>

                          {/* Health Factor Bar */}
                          <div className="mt-4 p-3 rounded-lg bg-dark-800/50">
                            <div className="flex items-center justify-between mb-2">
                              <span className="text-sm text-slate-400 flex items-center gap-1">
                                <Shield className="w-4 h-4" />
                                Health Factor
                              </span>
                              <span className={cn("font-bold", getHealthColor(position.healthFactor))}>
                                {position.healthFactor.toFixed(2)}
                              </span>
                            </div>
                            <div className="h-2 rounded-full bg-dark-700 overflow-hidden">
                              <motion.div
                                className={cn(
                                  "h-full rounded-full",
                                  position.healthFactor >= 2
                                    ? "bg-neon-green"
                                    : position.healthFactor >= 1.5
                                    ? "bg-green-400"
                                    : position.healthFactor >= 1.2
                                    ? "bg-yellow-400"
                                    : "bg-red-500"
                                )}
                                initial={{ width: 0 }}
                                animate={{
                                  width: `${Math.min((position.healthFactor / 3) * 100, 100)}%`,
                                }}
                              />
                            </div>
                            {position.healthFactor < 1.5 && (
                              <div className="flex items-center gap-2 mt-2 text-yellow-400 text-sm">
                                <AlertTriangle className="w-4 h-4" />
                                Consider adding margin to reduce liquidation risk
                              </div>
                            )}
                          </div>

                          {/* Actions */}
                          <div className="flex gap-3 mt-4">
                            {position.canSettle && (
                              <motion.button
                                onClick={() => handleSettle(position.id)}
                                disabled={isWorking}
                                className="flex-1 py-2.5 rounded-xl bg-neon-green/20 text-neon-green font-medium flex items-center justify-center gap-2 hover:bg-neon-green/30 transition-colors disabled:opacity-50"
                                whileHover={{ scale: 1.02 }}
                                whileTap={{ scale: 0.98 }}
                              >
                                <Zap className="w-4 h-4" />
                                {isWorking ? "Processing..." : "Settle"}
                              </motion.button>
                            )}
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </motion.div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
