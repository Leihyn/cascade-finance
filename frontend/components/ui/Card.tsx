"use client";

import { motion, HTMLMotionProps } from "framer-motion";
import { cn } from "@/lib/utils";

interface CardProps extends HTMLMotionProps<"div"> {
  variant?: "default" | "glass" | "gradient" | "neon";
  hover?: boolean;
  glow?: "cyan" | "purple" | "green" | "none";
}

export function Card({
  children,
  className,
  variant = "glass",
  hover = false,
  glow = "none",
  ...props
}: CardProps) {
  const variants = {
    default: "bg-dark-900 border border-white/10",
    glass: "glass-card",
    gradient: "bg-gradient-to-br from-dark-900 to-dark-950 border border-white/10",
    neon: "bg-dark-900/50 border border-neon-cyan/30 shadow-glow-cyan",
  };

  const glowStyles = {
    cyan: "shadow-glow-cyan",
    purple: "shadow-glow-purple",
    green: "shadow-glow-green",
    none: "",
  };

  return (
    <motion.div
      className={cn(
        "rounded-2xl p-6",
        variants[variant],
        hover && "hover-lift cursor-pointer",
        glowStyles[glow],
        className
      )}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      {...props}
    >
      {children}
    </motion.div>
  );
}

export function CardHeader({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex items-center justify-between mb-4", className)}>
      {children}
    </div>
  );
}

export function CardTitle({
  children,
  className,
  icon,
}: {
  children: React.ReactNode;
  className?: string;
  icon?: React.ReactNode;
}) {
  return (
    <h3 className={cn("text-lg font-bold flex items-center gap-2", className)}>
      {icon && <span className="text-neon-cyan">{icon}</span>}
      {children}
    </h3>
  );
}

export function CardContent({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <div className={cn("", className)}>{children}</div>;
}
