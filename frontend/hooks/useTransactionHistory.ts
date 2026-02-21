"use client";

import { useState, useEffect, useCallback } from "react";
import { usePublicClient } from "wagmi";
import { POSITION_MANAGER_ABI } from "@/lib/abis";

export type TransactionType = "opened" | "closed" | "settled" | "margin_added" | "margin_removed";

export interface Transaction {
  id: string;
  type: TransactionType;
  positionId: bigint;
  trader: string;
  timestamp: number;
  blockNumber: bigint;
  transactionHash: string;
  details: Record<string, unknown>;
}

export interface UseTransactionHistoryProps {
  positionManagerAddress: `0x${string}`;
  userAddress?: `0x${string}`;
  pageSize?: number;
}

export interface UseTransactionHistoryReturn {
  transactions: Transaction[];
  loading: boolean;
  error: string | null;
  hasMore: boolean;
  page: number;
  totalPages: number;
  filters: TransactionType[];
  setFilters: (filters: TransactionType[]) => void;
  nextPage: () => void;
  prevPage: () => void;
  refresh: () => void;
}

const ALL_TYPES: TransactionType[] = ["opened", "closed", "settled", "margin_added", "margin_removed"];

export function useTransactionHistory({
  positionManagerAddress,
  userAddress,
  pageSize = 10,
}: UseTransactionHistoryProps): UseTransactionHistoryReturn {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [filters, setFilters] = useState<TransactionType[]>(ALL_TYPES);
  const publicClient = usePublicClient();

  const fetchTransactions = useCallback(async () => {
    if (!publicClient) return;

    setLoading(true);
    setError(null);

    try {
      const allTransactions: Transaction[] = [];
      const currentBlock = await publicClient.getBlockNumber();
      const fromBlock = currentBlock > BigInt(5000) ? currentBlock - BigInt(5000) : BigInt(0);

      // Fetch PositionOpened events
      if (filters.includes("opened")) {
        const openedLogs = await publicClient.getLogs({
          address: positionManagerAddress,
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
          args: userAddress ? { trader: userAddress } : undefined,
        });

        for (const log of openedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          allTransactions.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "opened",
            positionId: log.args.positionId!,
            trader: log.args.trader!,
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            transactionHash: log.transactionHash,
            details: {
              isPayingFixed: log.args.isPayingFixed,
              notional: log.args.notional,
              fixedRate: log.args.fixedRate,
              margin: log.args.margin,
              maturity: log.args.maturity,
            },
          });
        }
      }

      // Fetch PositionClosed events
      if (filters.includes("closed")) {
        const closedLogs = await publicClient.getLogs({
          address: positionManagerAddress,
          event: {
            type: "event",
            name: "PositionClosed",
            inputs: [
              { indexed: true, name: "positionId", type: "uint256" },
              { indexed: true, name: "trader", type: "address" },
              { indexed: false, name: "finalPnL", type: "int256" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
          args: userAddress ? { trader: userAddress } : undefined,
        });

        for (const log of closedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          allTransactions.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "closed",
            positionId: log.args.positionId!,
            trader: log.args.trader!,
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            transactionHash: log.transactionHash,
            details: {
              finalPnL: log.args.finalPnL,
            },
          });
        }
      }

      // Fetch PositionSettled events
      if (filters.includes("settled")) {
        const settledLogs = await publicClient.getLogs({
          address: positionManagerAddress,
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
          allTransactions.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "settled",
            positionId: log.args.positionId!,
            trader: "",
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            transactionHash: log.transactionHash,
            details: {
              settlementAmount: log.args.settlementAmount,
              newMargin: log.args.newMargin,
            },
          });
        }
      }

      // Fetch MarginAdded events
      if (filters.includes("margin_added")) {
        const addedLogs = await publicClient.getLogs({
          address: positionManagerAddress,
          event: {
            type: "event",
            name: "MarginAdded",
            inputs: [
              { indexed: true, name: "positionId", type: "uint256" },
              { indexed: false, name: "amount", type: "uint256" },
              { indexed: false, name: "newMargin", type: "uint256" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        });

        for (const log of addedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          allTransactions.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "margin_added",
            positionId: log.args.positionId!,
            trader: "",
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            transactionHash: log.transactionHash,
            details: {
              amount: log.args.amount,
              newMargin: log.args.newMargin,
            },
          });
        }
      }

      // Fetch MarginRemoved events
      if (filters.includes("margin_removed")) {
        const removedLogs = await publicClient.getLogs({
          address: positionManagerAddress,
          event: {
            type: "event",
            name: "MarginRemoved",
            inputs: [
              { indexed: true, name: "positionId", type: "uint256" },
              { indexed: false, name: "amount", type: "uint256" },
              { indexed: false, name: "newMargin", type: "uint256" },
            ],
          },
          fromBlock,
          toBlock: currentBlock,
        });

        for (const log of removedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          allTransactions.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: "margin_removed",
            positionId: log.args.positionId!,
            trader: "",
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            transactionHash: log.transactionHash,
            details: {
              amount: log.args.amount,
              newMargin: log.args.newMargin,
            },
          });
        }
      }

      // Sort by timestamp descending
      allTransactions.sort((a, b) => b.timestamp - a.timestamp);
      setTransactions(allTransactions);
    } catch (e) {
      console.error("Error fetching transactions:", e);
      setError("Failed to fetch transaction history");
    }

    setLoading(false);
  }, [publicClient, positionManagerAddress, userAddress, filters]);

  useEffect(() => {
    fetchTransactions();
  }, [fetchTransactions]);

  // Pagination
  const totalPages = Math.ceil(transactions.length / pageSize);
  const paginatedTransactions = transactions.slice(
    (page - 1) * pageSize,
    page * pageSize
  );

  const nextPage = useCallback(() => {
    if (page < totalPages) setPage((p) => p + 1);
  }, [page, totalPages]);

  const prevPage = useCallback(() => {
    if (page > 1) setPage((p) => p - 1);
  }, [page]);

  const handleSetFilters = useCallback((newFilters: TransactionType[]) => {
    setFilters(newFilters);
    setPage(1);
  }, []);

  return {
    transactions: paginatedTransactions,
    loading,
    error,
    hasMore: page < totalPages,
    page,
    totalPages,
    filters,
    setFilters: handleSetFilters,
    nextPage,
    prevPage,
    refresh: fetchTransactions,
  };
}
