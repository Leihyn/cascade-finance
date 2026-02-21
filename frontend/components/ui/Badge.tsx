"use client";

import { cn } from "@/lib/utils";

export interface BadgeProps {
  children: React.ReactNode;
  variant?: "default" | "success" | "warning" | "danger" | "info" | "purple" | "gradient";
  size?: "sm" | "md" | "lg";
  className?: string;
  icon?: React.ReactNode;
  pulse?: boolean;
}

export function Badge({
  children,
  variant = "default",
  size = "md",
  className,
  icon,
  pulse = false,
}: BadgeProps) {
  const variants = {
    default: "bg-white/10 text-slate-300 border-white/10",
    success: "bg-neon-green/10 text-neon-green border-neon-green/30",
    warning: "bg-yellow-500/10 text-yellow-400 border-yellow-500/30",
    danger: "bg-red-500/10 text-red-400 border-red-500/30",
    info: "bg-neon-cyan/10 text-neon-cyan border-neon-cyan/30",
    purple: "bg-neon-purple/10 text-neon-purple border-neon-purple/30",
    gradient:
      "bg-gradient-to-r from-neon-cyan/10 to-neon-purple/10 text-white border-neon-cyan/30",
  };

  const sizes = {
    sm: "px-2 py-0.5 text-xs gap-1",
    md: "px-3 py-1 text-xs gap-1.5",
    lg: "px-4 py-1.5 text-sm gap-2",
  };

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border font-medium",
        variants[variant],
        sizes[size],
        className
      )}
    >
      {pulse && (
        <span
          className={cn(
            "w-1.5 h-1.5 rounded-full animate-pulse",
            variant === "success" && "bg-neon-green",
            variant === "warning" && "bg-yellow-400",
            variant === "danger" && "bg-red-400",
            variant === "info" && "bg-neon-cyan",
            variant === "purple" && "bg-neon-purple",
            variant === "default" && "bg-slate-400",
            variant === "gradient" && "bg-neon-cyan"
          )}
        />
      )}
      {icon}
      {children}
    </span>
  );
}

export interface StatusBadgeProps {
  status: "active" | "pending" | "completed" | "failed" | "expired" | "liquidated";
  size?: "sm" | "md" | "lg";
  className?: string;
}

export function StatusBadge({ status, size = "md", className }: StatusBadgeProps) {
  const statusConfig = {
    active: { variant: "success" as const, label: "Active", pulse: true },
    pending: { variant: "warning" as const, label: "Pending", pulse: true },
    completed: { variant: "info" as const, label: "Completed", pulse: false },
    failed: { variant: "danger" as const, label: "Failed", pulse: false },
    expired: { variant: "default" as const, label: "Expired", pulse: false },
    liquidated: { variant: "danger" as const, label: "Liquidated", pulse: false },
  };

  const config = statusConfig[status];

  return (
    <Badge
      variant={config.variant}
      size={size}
      pulse={config.pulse}
      className={className}
    >
      {config.label}
    </Badge>
  );
}

export interface HealthBadgeProps {
  healthFactor: number;
  size?: "sm" | "md" | "lg";
  className?: string;
}

export function HealthBadge({ healthFactor, size = "md", className }: HealthBadgeProps) {
  let variant: BadgeProps["variant"];
  let label: string;

  if (healthFactor >= 2) {
    variant = "success";
    label = "Healthy";
  } else if (healthFactor >= 1.5) {
    variant = "info";
    label = "Safe";
  } else if (healthFactor >= 1.2) {
    variant = "warning";
    label = "Caution";
  } else {
    variant = "danger";
    label = "At Risk";
  }

  return (
    <Badge variant={variant} size={size} className={className}>
      {healthFactor.toFixed(2)} - {label}
    </Badge>
  );
}

export interface NetworkBadgeProps {
  network: string;
  isConnected?: boolean;
  size?: "sm" | "md" | "lg";
  className?: string;
}

export function NetworkBadge({
  network,
  isConnected = true,
  size = "md",
  className,
}: NetworkBadgeProps) {
  return (
    <Badge
      variant={isConnected ? "success" : "danger"}
      size={size}
      pulse={isConnected}
      className={className}
    >
      {network}
    </Badge>
  );
}

export interface CountBadge {
  count: number;
  max?: number;
  size?: "sm" | "md";
  className?: string;
}

export function CountBadge({ count, max = 99, size = "sm", className }: CountBadge) {
  const displayCount = count > max ? `${max}+` : count;

  return (
    <span
      className={cn(
        "inline-flex items-center justify-center rounded-full bg-neon-cyan text-dark-950 font-bold",
        size === "sm" ? "min-w-5 h-5 px-1.5 text-xs" : "min-w-6 h-6 px-2 text-sm",
        className
      )}
    >
      {displayCount}
    </span>
  );
}
