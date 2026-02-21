import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(
  num: number | bigint,
  options: {
    decimals?: number;
    compact?: boolean;
    prefix?: string;
    suffix?: string;
  } = {}
): string {
  const { decimals = 2, compact = false, prefix = "", suffix = "" } = options;

  const value = typeof num === "bigint" ? Number(num) : num;

  if (compact && Math.abs(value) >= 1000) {
    const suffixes = ["", "K", "M", "B", "T"];
    const tier = Math.floor(Math.log10(Math.abs(value)) / 3);
    const scaled = value / Math.pow(10, tier * 3);
    return `${prefix}${scaled.toFixed(1)}${suffixes[tier]}${suffix}`;
  }

  return `${prefix}${value.toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })}${suffix}`;
}

export function formatPercent(value: number, decimals = 2): string {
  return `${(value * 100).toFixed(decimals)}%`;
}

export function formatRate(rate: bigint, decimals = 2): string {
  const rateNum = Number(rate) / 1e18;
  return `${(rateNum * 100).toFixed(decimals)}%`;
}

export function formatUSD(value: number | bigint, decimals = 2): string {
  return formatNumber(value, { prefix: "$", decimals });
}

export function shortenAddress(address: string, chars = 4): string {
  return `${address.slice(0, chars + 2)}...${address.slice(-chars)}`;
}

export function formatTimestamp(timestamp: number): string {
  return new Date(timestamp * 1000).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatTimeRemaining(seconds: number): string {
  if (seconds <= 0) return "Expired";

  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);

  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

export function getHealthColor(healthFactor: number): string {
  if (healthFactor >= 2) return "text-neon-green";
  if (healthFactor >= 1.5) return "text-green-400";
  if (healthFactor >= 1.2) return "text-yellow-400";
  if (healthFactor >= 1) return "text-orange-400";
  return "text-red-500";
}

export function getHealthBgColor(healthFactor: number): string {
  if (healthFactor >= 2) return "bg-neon-green/20";
  if (healthFactor >= 1.5) return "bg-green-400/20";
  if (healthFactor >= 1.2) return "bg-yellow-400/20";
  if (healthFactor >= 1) return "bg-orange-400/20";
  return "bg-red-500/20";
}
