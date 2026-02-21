"use client";

import { useTransactionHistory } from "@/hooks/useTransactionHistory";
import { TransactionFilters } from "./TransactionFilters";
import { TransactionRow } from "./TransactionRow";

interface Props {
  contracts: {
    positionManager: `0x${string}`;
  };
  userAddress?: `0x${string}`;
  showFilters?: boolean;
  pageSize?: number;
  explorerUrl?: string;
}

export function TransactionHistory({
  contracts,
  userAddress,
  showFilters = true,
  pageSize = 10,
  explorerUrl = "https://sepolia.basescan.org",
}: Props) {
  const {
    transactions,
    loading,
    error,
    page,
    totalPages,
    hasMore,
    filters,
    setFilters,
    nextPage,
    prevPage,
    refresh,
  } = useTransactionHistory({
    positionManagerAddress: contracts.positionManager,
    userAddress,
    pageSize,
  });

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl p-4 sm:p-6 border border-gray-200 dark:border-gray-800">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
        <h2 className="text-lg sm:text-xl font-semibold">Transaction History</h2>
        <button
          type="button"
          onClick={refresh}
          disabled={loading}
          className="text-xs px-3 py-1.5 min-h-[32px] bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition disabled:opacity-50"
        >
          {loading ? "Loading..." : "Refresh"}
        </button>
      </div>

      {/* Filters */}
      {showFilters && (
        <div className="mb-4">
          <TransactionFilters activeFilters={filters} onFilterChange={setFilters} />
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="p-4 bg-red-50 dark:bg-red-900/30 rounded-lg text-red-600 dark:text-red-400 text-sm mb-4">
          {error}
        </div>
      )}

      {/* Loading State */}
      {loading && transactions.length === 0 ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <div className="animate-pulse">Loading transactions...</div>
        </div>
      ) : transactions.length === 0 ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <p>No transactions found</p>
          {filters.length === 0 && (
            <p className="text-sm mt-2">Try enabling some filters above</p>
          )}
        </div>
      ) : (
        <>
          {/* Transaction List */}
          <div className="space-y-2">
            {transactions.map((tx) => (
              <TransactionRow
                key={tx.id}
                transaction={tx}
                explorerUrl={explorerUrl}
              />
            ))}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between">
              <button
                type="button"
                onClick={prevPage}
                disabled={page === 1 || loading}
                className="px-3 py-1.5 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Previous
              </button>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                Page {page} of {totalPages}
              </span>
              <button
                type="button"
                onClick={nextPage}
                disabled={!hasMore || loading}
                className="px-3 py-1.5 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Next
              </button>
            </div>
          )}
        </>
      )}

      {/* User filter indicator */}
      {userAddress && (
        <div className="mt-4 text-xs text-gray-500 dark:text-gray-400 text-center">
          Showing transactions for your address only
        </div>
      )}
    </div>
  );
}
