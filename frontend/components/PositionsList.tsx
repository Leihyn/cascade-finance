"use client";

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { formatUnits } from "viem";
import { POSITION_MANAGER_ABI, MARGIN_ENGINE_ABI, SETTLEMENT_ENGINE_ABI } from "@/lib/abis";
import { useState, useEffect, useCallback } from "react";
import { usePublicClient } from "wagmi";

interface Props {
  contracts: {
    positionManager: `0x${string}`;
    marginEngine: `0x${string}`;
    settlementEngine: `0x${string}`;
  };
  userAddress: `0x${string}`;
}

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
}

export function PositionsList({ contracts, userAddress }: Props) {
  const [positions, setPositions] = useState<Position[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date());
  const publicClient = usePublicClient();

  // Get next position ID to know how many to query
  const { data: nextPositionId, refetch: refetchNextId } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "nextPositionId",
  });

  const { writeContract, isPending, data: hash } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  const fetchPositions = useCallback(async () => {
      if (!publicClient) return;

      // No positions exist yet
      if (!nextPositionId || nextPositionId === BigInt(0)) {
        setPositions([]);
        setLoading(false);
        setLastRefresh(new Date());
        return;
      }

      setLoading(true);

      try {
        // Build array of position IDs to fetch
        const positionIds = Array.from(
          { length: Number(nextPositionId) },
          (_, i) => BigInt(i)
        );

        // Batch fetch all positions in a single multicall
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

        // Parse positions and identify active ones for settlement queries
        const parsedPositions: Position[] = [];
        const activePositionIds: bigint[] = [];

        for (let i = 0; i < positionsData.length; i++) {
          const result = positionsData[i];
          if (result.status === "failure") {
            console.error(`Error fetching position ${i}:`, result.error);
            continue;
          }

          const data = result.result as [string, boolean, number, number, boolean, bigint, bigint, bigint, bigint, number, bigint];
          const [trader, isPayingFixed, startTime, maturity, isActive, notional, margin, fixedRate, accumulatedPnL, lastSettlement] = data;

          // Debug logging
          console.log(`[PositionsList] Position ${i}:`, {
            trader,
            isActive,
            notional: notional.toString(),
            margin: margin.toString(),
            accumulatedPnL: accumulatedPnL.toString(),
            fixedRate: fixedRate.toString(),
          });

          parsedPositions.push({
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
          });

          if (isActive) {
            activePositionIds.push(BigInt(i));
          }
        }

        // Batch fetch settlement data for active positions only
        if (activePositionIds.length > 0) {
          const settlementCalls = activePositionIds.flatMap((id) => [
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
          ]);

          const settlementData = await publicClient.multicall({
            contracts: settlementCalls,
            allowFailure: true,
          });

          // Map settlement data back to positions
          for (let i = 0; i < activePositionIds.length; i++) {
            const positionId = activePositionIds[i];
            const pendingResult = settlementData[i * 2];
            const canSettleResult = settlementData[i * 2 + 1];

            // Debug logging
            console.log(`[PositionsList] Position ${positionId.toString()} settlement:`, {
              pendingResult: pendingResult.status === "success" ? (pendingResult.result as bigint).toString() : `failed: ${pendingResult.error}`,
              canSettleResult: canSettleResult.status === "success" ? canSettleResult.result : `failed: ${canSettleResult.error}`,
            });

            const position = parsedPositions.find((p) => p.id === positionId);
            if (position) {
              if (pendingResult.status === "success") {
                position.pendingPnL = pendingResult.result as bigint;
              }
              if (canSettleResult.status === "success") {
                position.canSettle = canSettleResult.result as boolean;
              }
            }
          }
        }

        setPositions(parsedPositions);
      } catch (e) {
        console.error("Error fetching positions:", e);
      } finally {
        setLoading(false);
        setLastRefresh(new Date());
      }
  }, [nextPositionId, publicClient, contracts.positionManager, contracts.settlementEngine]);

  // Refetch on mount to get fresh data
  useEffect(() => {
    refetchNextId();
  }, [refetchNextId]);

  // Fetch positions when nextPositionId changes
  useEffect(() => {
    fetchPositions();
  }, [fetchPositions]);

  // Auto-refresh every 30 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      refetchNextId();
    }, 30000);
    return () => clearInterval(interval);
  }, [refetchNextId]);

  // Refetch positions after transaction confirms
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

  const handleCloseMatured = (positionId: bigint) => {
    writeContract({
      address: contracts.settlementEngine,
      abi: SETTLEMENT_ENGINE_ABI,
      functionName: "closeMaturedPosition",
      args: [positionId],
    });
  };

  const formatRate = (rate: bigint) => {
    return (Number(formatUnits(rate, 18)) * 100).toFixed(2) + "%";
  };

  const formatUSDC = (amount: bigint) => {
    return "$" + Number(formatUnits(amount, 6)).toLocaleString();
  };

  const formatPnL = (pnl: bigint) => {
    const value = Number(formatUnits(pnl, 6));
    const formatted = "$" + Math.abs(value).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (value >= 0) {
      return <span className="text-green-600 dark:text-green-400">+{formatted}</span>;
    }
    return <span className="text-red-600 dark:text-red-400">-{formatted}</span>;
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString();
  };

  const isMatured = (maturity: number) => {
    return Date.now() / 1000 > maturity;
  };

  const isWorking = isPending || isConfirming;

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl p-4 sm:p-6 border border-gray-200 dark:border-gray-800">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 mb-6">
        <h2 className="text-lg sm:text-xl font-semibold">All Positions</h2>
        <div className="flex items-center gap-3">
          <span className="text-xs text-gray-500 hidden sm:inline">
            Updated: {lastRefresh.toLocaleTimeString()}
          </span>
          <button
            onClick={() => refetchNextId()}
            disabled={loading}
            className="text-xs px-3 py-1.5 min-h-[32px] bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition disabled:opacity-50"
          >
            {loading ? "..." : "Refresh"}
          </button>
        </div>
      </div>

      {loading ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <p>Loading positions...</p>
        </div>
      ) : positions.length === 0 ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <p>No positions yet</p>
          <p className="text-sm mt-2">Open a position to get started</p>
        </div>
      ) : (
        <div className="space-y-4">
          {positions.map((position) => (
            <div key={position.id.toString()} className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
              <div className="flex justify-between items-start mb-4">
                <div className="flex flex-wrap gap-2">
                  {position.trader.toLowerCase() === userAddress.toLowerCase() && (
                    <span className="text-xs px-2 py-1 rounded bg-blue-100 dark:bg-blue-600 text-blue-700 dark:text-white">
                      Yours
                    </span>
                  )}
                  <span className={`text-xs px-2 py-1 rounded text-white ${
                    position.isPayingFixed ? "bg-indigo-600" : "bg-purple-600"
                  }`}>
                    {position.isPayingFixed ? "Pay Fixed" : "Pay Floating"}
                  </span>
                  <span className={`text-xs px-2 py-1 rounded text-white ${
                    position.isActive
                      ? (isMatured(position.maturity) ? "bg-yellow-500" : "bg-green-600")
                      : "bg-gray-500"
                  }`}>
                    {position.isActive
                      ? (isMatured(position.maturity) ? "Matured" : "Active")
                      : "Closed"
                    }
                  </span>
                </div>
                <div className="text-right">
                  <div className="text-sm text-gray-500 dark:text-gray-400">Position #{position.id.toString()}</div>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4 mb-4">
                <div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">Notional</div>
                  <div className="font-semibold text-sm sm:text-base">{formatUSDC(position.notional)}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">Fixed Rate</div>
                  <div className="font-semibold text-sm sm:text-base">{formatRate(position.fixedRate)}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">Margin</div>
                  <div className="font-semibold text-sm sm:text-base">{formatUSDC(position.margin)}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">Settled PnL</div>
                  <div className="font-semibold text-sm sm:text-base">{formatPnL(position.accumulatedPnL)}</div>
                </div>
              </div>

              {position.isActive && (
                <div className="bg-gray-100 dark:bg-gray-700/50 rounded-lg p-3 mb-4">
                  <div className="flex justify-between items-center">
                    <div>
                      <span className="text-xs text-gray-500 dark:text-gray-400">Pending Settlement: </span>
                      <span className="font-semibold">{formatPnL(position.pendingPnL)}</span>
                      {position.pendingPnL === BigInt(0) && (
                        <span className="text-xs text-gray-500 ml-2">(no change yet)</span>
                      )}
                    </div>
                    {position.canSettle ? (
                      <span className="text-xs text-green-600 dark:text-green-400 animate-pulse">Ready to settle</span>
                    ) : (
                      <span className="text-xs text-yellow-600 dark:text-yellow-400">
                        Next: {new Date((position.lastSettlement + 3600) * 1000).toLocaleTimeString()}
                      </span>
                    )}
                  </div>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
                <div>
                  <span className="text-gray-500 dark:text-gray-400">Started: </span>
                  <span>{formatDate(position.startTime)}</span>
                </div>
                <div>
                  <span className="text-gray-500 dark:text-gray-400">Matures: </span>
                  <span>{formatDate(position.maturity)}</span>
                </div>
              </div>

              {position.isActive && position.trader.toLowerCase() === userAddress.toLowerCase() && (
                <div className="flex flex-col sm:flex-row gap-2">
                  <button
                    onClick={() => handleSettle(position.id)}
                    disabled={isWorking || !position.canSettle}
                    className={`flex-1 py-2 min-h-[44px] rounded text-sm font-medium text-white transition disabled:opacity-50 ${
                      position.canSettle
                        ? "bg-green-600 hover:bg-green-500"
                        : "bg-gray-400 dark:bg-gray-600"
                    }`}
                  >
                    {isWorking ? "..." : position.canSettle ? "Settle Now" : "Settle (wait 1hr)"}
                  </button>
                  {isMatured(position.maturity) && (
                    <button
                      onClick={() => handleCloseMatured(position.id)}
                      disabled={isWorking}
                      className="flex-1 py-2 min-h-[44px] bg-red-600 hover:bg-red-500 text-white rounded text-sm font-medium transition disabled:opacity-50"
                    >
                      {isWorking ? "..." : "Close"}
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}

          <div className="text-center text-sm text-gray-500 mt-4">
            Showing {positions.length} of {(nextPositionId ? nextPositionId - BigInt(1) : BigInt(0)).toString()} total positions
          </div>
        </div>
      )}
    </div>
  );
}
