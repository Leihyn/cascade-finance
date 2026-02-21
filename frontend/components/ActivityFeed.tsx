"use client";

import { useEffect, useState } from "react";
import { usePublicClient } from "wagmi";
import { formatUnits } from "viem";
import { POSITION_MANAGER_ABI } from "@/lib/abis";

interface Props {
  contracts: {
    positionManager: `0x${string}`;
  };
}

interface Activity {
  id: string;
  type: "opened" | "closed" | "settled" | "margin";
  positionId: bigint;
  trader: string;
  timestamp: number;
  blockNumber: bigint;
  details: Record<string, unknown>;
}

export function ActivityFeed({ contracts }: Props) {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [loading, setLoading] = useState(true);
  const publicClient = usePublicClient();

  useEffect(() => {
    async function fetchEvents() {
      if (!publicClient) return;

      setLoading(true);
      const allActivities: Activity[] = [];

      try {
        // Get recent blocks (last ~1000 blocks for demo)
        const currentBlock = await publicClient.getBlockNumber();
        const fromBlock = currentBlock > BigInt(1000) ? currentBlock - BigInt(1000) : BigInt(0);

        // Fetch PositionOpened events
        const openedLogs = await publicClient.getLogs({
          address: contracts.positionManager,
          event: {
            type: "event",
            name: "PositionOpened",
            inputs: [
              { indexed: true, name: "positionId", type: "uint256" },
              { indexed: true, name: "trader", type: "address" },
              { indexed: false, name: "isPayingFixed", type: "bool" },
              { indexed: false, name: "notional", type: "uint256" },
              { indexed: false, name: "fixedRate", type: "uint256" },
              { indexed: false, name: "margin", type: "uint256" },
              { indexed: false, name: "maturity", type: "uint256" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        });

        for (const log of openedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          allActivities.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "opened",
            positionId: log.args.positionId!,
            trader: log.args.trader!,
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            details: {
              isPayingFixed: log.args.isPayingFixed,
              notional: log.args.notional,
              fixedRate: log.args.fixedRate,
              margin: log.args.margin,
            },
          });
        }

        // Fetch PositionSettled events
        const settledLogs = await publicClient.getLogs({
          address: contracts.positionManager,
          event: {
            type: "event",
            name: "PositionSettled",
            inputs: [
              { indexed: true, name: "positionId", type: "uint256" },
              { indexed: false, name: "settlementAmount", type: "int256" },
              { indexed: false, name: "newMargin", type: "int256" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        });

        for (const log of settledLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          allActivities.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "settled",
            positionId: log.args.positionId!,
            trader: "",
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            details: {
              settlementAmount: log.args.settlementAmount,
              newMargin: log.args.newMargin,
            },
          });
        }

        // Sort by timestamp descending
        allActivities.sort((a, b) => b.timestamp - a.timestamp);
        setActivities(allActivities.slice(0, 20)); // Show last 20
      } catch (e) {
        console.error("Error fetching events:", e);
      }

      setLoading(false);
    }

    fetchEvents();
  }, [publicClient, contracts.positionManager]);

  const formatAmount = (amount: bigint) => {
    return "$" + Number(formatUnits(amount, 6)).toLocaleString();
  };

  const formatRate = (rate: bigint) => {
    return (Number(formatUnits(rate, 18)) * 100).toFixed(2) + "%";
  };

  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp * 1000);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    if (diff < 60000) return "Just now";
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return date.toLocaleDateString();
  };

  const shortenAddress = (addr: string) => {
    return addr.slice(0, 6) + "..." + addr.slice(-4);
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case "opened": return "🆕";
      case "closed": return "🔒";
      case "settled": return "💰";
      case "margin": return "➕";
      default: return "📝";
    }
  };

  const getActivityColor = (type: string) => {
    switch (type) {
      case "opened": return "text-green-600 dark:text-green-400";
      case "closed": return "text-red-600 dark:text-red-400";
      case "settled": return "text-blue-600 dark:text-blue-400";
      case "margin": return "text-yellow-600 dark:text-yellow-400";
      default: return "text-gray-600 dark:text-gray-400";
    }
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl p-4 sm:p-6 border border-gray-200 dark:border-gray-800">
      <h2 className="text-lg sm:text-xl font-semibold mb-6">Recent Activity</h2>

      {loading ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <p>Loading activity...</p>
        </div>
      ) : activities.length === 0 ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <p>No recent activity</p>
        </div>
      ) : (
        <div className="space-y-3">
          {activities.map((activity) => (
            <div
              key={activity.id}
              className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg"
            >
              <span className="text-xl">{getActivityIcon(activity.type)}</span>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className={`font-medium ${getActivityColor(activity.type)}`}>
                    {activity.type === "opened" && "Position Opened"}
                    {activity.type === "closed" && "Position Closed"}
                    {activity.type === "settled" && "Settlement"}
                    {activity.type === "margin" && "Margin Added"}
                  </span>
                  <span className="text-xs text-gray-500">
                    #{activity.positionId.toString()}
                  </span>
                </div>
                <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  {activity.type === "opened" && (
                    <>
                      {(activity.details.isPayingFixed as boolean) ? "Pay Fixed" : "Pay Floating"} •{" "}
                      {formatAmount(activity.details.notional as bigint)} notional •{" "}
                      {formatRate(activity.details.fixedRate as bigint)} fixed
                    </>
                  )}
                  {activity.type === "settled" && (
                    <>
                      Settlement: {formatAmount(BigInt(Math.abs(Number(activity.details.settlementAmount))))}
                    </>
                  )}
                </div>
                {activity.trader && (
                  <div className="text-xs text-gray-400 dark:text-gray-500 mt-1">
                    by {shortenAddress(activity.trader)}
                  </div>
                )}
              </div>
              <div className="text-xs text-gray-400 dark:text-gray-500">
                {formatTime(activity.timestamp)}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
