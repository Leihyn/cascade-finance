"use client";

import { TransactionType } from "@/hooks/useTransactionHistory";

interface Props {
  activeFilters: TransactionType[];
  onFilterChange: (filters: TransactionType[]) => void;
}

const FILTER_OPTIONS: { value: TransactionType; label: string; color: string }[] = [
  { value: "opened", label: "Opened", color: "green" },
  { value: "closed", label: "Closed", color: "red" },
  { value: "settled", label: "Settled", color: "blue" },
  { value: "margin_added", label: "Margin +", color: "indigo" },
  { value: "margin_removed", label: "Margin -", color: "orange" },
];

export function TransactionFilters({ activeFilters, onFilterChange }: Props) {
  const toggleFilter = (filter: TransactionType) => {
    if (activeFilters.includes(filter)) {
      onFilterChange(activeFilters.filter((f) => f !== filter));
    } else {
      onFilterChange([...activeFilters, filter]);
    }
  };

  const selectAll = () => {
    onFilterChange(FILTER_OPTIONS.map((o) => o.value));
  };

  const clearAll = () => {
    onFilterChange([]);
  };

  const getButtonClasses = (filter: TransactionType, color: string) => {
    const isActive = activeFilters.includes(filter);
    const colorClasses: Record<string, string> = {
      green: isActive
        ? "bg-green-500 text-white border-green-500"
        : "bg-transparent text-green-600 dark:text-green-400 border-green-300 dark:border-green-700 hover:bg-green-50 dark:hover:bg-green-900/30",
      red: isActive
        ? "bg-red-500 text-white border-red-500"
        : "bg-transparent text-red-600 dark:text-red-400 border-red-300 dark:border-red-700 hover:bg-red-50 dark:hover:bg-red-900/30",
      blue: isActive
        ? "bg-blue-500 text-white border-blue-500"
        : "bg-transparent text-blue-600 dark:text-blue-400 border-blue-300 dark:border-blue-700 hover:bg-blue-50 dark:hover:bg-blue-900/30",
      indigo: isActive
        ? "bg-indigo-500 text-white border-indigo-500"
        : "bg-transparent text-indigo-600 dark:text-indigo-400 border-indigo-300 dark:border-indigo-700 hover:bg-indigo-50 dark:hover:bg-indigo-900/30",
      orange: isActive
        ? "bg-orange-500 text-white border-orange-500"
        : "bg-transparent text-orange-600 dark:text-orange-400 border-orange-300 dark:border-orange-700 hover:bg-orange-50 dark:hover:bg-orange-900/30",
    };
    return colorClasses[color] || colorClasses.blue;
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {FILTER_OPTIONS.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => toggleFilter(option.value)}
            className={`px-3 py-1.5 text-xs font-medium rounded-full border transition ${getButtonClasses(
              option.value,
              option.color
            )}`}
          >
            {option.label}
          </button>
        ))}
      </div>
      <div className="flex gap-2 text-xs">
        <button
          type="button"
          onClick={selectAll}
          className="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
        >
          Select All
        </button>
        <span className="text-gray-300 dark:text-gray-600">|</span>
        <button
          type="button"
          onClick={clearAll}
          className="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
        >
          Clear All
        </button>
      </div>
    </div>
  );
}
