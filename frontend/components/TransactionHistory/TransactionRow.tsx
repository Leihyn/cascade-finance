"use client";

import { formatUnits } from "viem";
import { Transaction, TransactionType } from "@/hooks/useTransactionHistory";

interface Props {
  transaction: Transaction;
  explorerUrl?: string;
}

const TYPE_CONFIG: Record<
  TransactionType,
  { label: string; icon: string; color: string; bgColor: string }
> = {
  opened: {
    label: "Position Opened",
    icon: "+",
    color: "text-green-600 dark:text-green-400",
    bgColor: "bg-green-100 dark:bg-green-900/30",
  },
  closed: {
    label: "Position Closed",
    icon: "x",
    color: "text-red-600 dark:text-red-400",
    bgColor: "bg-red-100 dark:bg-red-900/30",
  },
  settled: {
    label: "Settlement",
    icon: "$",
    color: "text-blue-600 dark:text-blue-400",
    bgColor: "bg-blue-100 dark:bg-blue-900/30",
  },
  margin_added: {
    label: "Margin Added",
    icon: "^",
    color: "text-indigo-600 dark:text-indigo-400",
    bgColor: "bg-indigo-100 dark:bg-indigo-900/30",
  },
  margin_removed: {
    label: "Margin Removed",
    icon: "v",
    color: "text-orange-600 dark:text-orange-400",
    bgColor: "bg-orange-100 dark:bg-orange-900/30",
  },
};

export function TransactionRow({ transaction, explorerUrl }: Props) {
  const config = TYPE_CONFIG[transaction.type];

  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp * 1000);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    if (diff < 60000) return "Just now";
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return date.toLocaleDateString();
  };

  const formatUSDC = (amount: bigint | unknown) => {
    if (typeof amount !== "bigint") return "$0";
    return "$" + Number(formatUnits(amount, 6)).toLocaleString();
  };

  const formatRate = (rate: bigint | unknown) => {
    if (typeof rate !== "bigint") return "0%";
    return (Number(formatUnits(rate, 18)) * 100).toFixed(2) + "%";
  };

  const formatPnL = (pnl: bigint | unknown) => {
    if (typeof pnl !== "bigint") return "$0";
    const value = Number(formatUnits(pnl, 6));
    const formatted =
      "$" +
      Math.abs(value).toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
    if (value >= 0) {
      return <span className="text-green-600 dark:text-green-400">+{formatted}</span>;
    }
    return <span className="text-red-600 dark:text-red-400">-{formatted}</span>;
  };

  const shortenHash = (hash: string) => {
    return hash.slice(0, 6) + "..." + hash.slice(-4);
  };

  const shortenAddress = (addr: string) => {
    if (!addr) return "";
    return addr.slice(0, 6) + "..." + addr.slice(-4);
  };

  const renderDetails = () => {
    switch (transaction.type) {
      case "opened":
        return (
          <div className="text-xs text-gray-500 dark:text-gray-400 space-y-0.5">
            <div>
              {(transaction.details.isPayingFixed as boolean) ? "Pay Fixed" : "Pay Floating"} •{" "}
              {formatUSDC(transaction.details.notional)} notional
            </div>
            <div>
              Rate: {formatRate(transaction.details.fixedRate)} •{" "}
              Margin: {formatUSDC(transaction.details.margin)}
            </div>
          </div>
        );
      case "closed":
        return (
          <div className="text-xs text-gray-500 dark:text-gray-400">
            Final P&L: {formatPnL(transaction.details.finalPnL)}
          </div>
        );
      case "settled":
        return (
          <div className="text-xs text-gray-500 dark:text-gray-400">
            Settlement: {formatPnL(transaction.details.settlementAmount)} •{" "}
            New Margin: {formatUSDC(transaction.details.newMargin)}
          </div>
        );
      case "margin_added":
        return (
          <div className="text-xs text-gray-500 dark:text-gray-400">
            Added: {formatUSDC(transaction.details.amount)} •{" "}
            New Margin: {formatUSDC(transaction.details.newMargin)}
          </div>
        );
      case "margin_removed":
        return (
          <div className="text-xs text-gray-500 dark:text-gray-400">
            Removed: {formatUSDC(transaction.details.amount)} •{" "}
            New Margin: {formatUSDC(transaction.details.newMargin)}
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-750 transition">
      {/* Icon */}
      <div
        className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${config.bgColor} ${config.color}`}
      >
        {config.icon}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <span className={`font-medium text-sm ${config.color}`}>{config.label}</span>
            <span className="text-xs text-gray-400 dark:text-gray-500">
              #{transaction.positionId.toString()}
            </span>
          </div>
          <span className="text-xs text-gray-400 dark:text-gray-500">
            {formatTime(transaction.timestamp)}
          </span>
        </div>

        {/* Details */}
        <div className="mt-1">{renderDetails()}</div>

        {/* Footer */}
        <div className="mt-2 flex items-center gap-3 text-xs text-gray-400 dark:text-gray-500">
          {transaction.trader && (
            <span title={transaction.trader}>By: {shortenAddress(transaction.trader)}</span>
          )}
          {explorerUrl ? (
            <a
              href={`${explorerUrl}/tx/${transaction.transactionHash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-indigo-500 dark:hover:text-indigo-400"
            >
              {shortenHash(transaction.transactionHash)}
            </a>
          ) : (
            <span>{shortenHash(transaction.transactionHash)}</span>
          )}
        </div>
      </div>
    </div>
  );
}
