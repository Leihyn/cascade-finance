"use client";

import { createContext, useContext, useState, useCallback, ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { CheckCircle, XCircle, AlertTriangle, Info, X } from "lucide-react";
import { cn } from "@/lib/utils";

type ToastType = "success" | "error" | "warning" | "info";

interface Toast {
  id: string;
  type: ToastType;
  title: string;
  message?: string;
  duration?: number;
}

interface ToastContextValue {
  toasts: Toast[];
  addToast: (toast: Omit<Toast, "id">) => void;
  removeToast: (id: string) => void;
  success: (title: string, message?: string) => void;
  error: (title: string, message?: string) => void;
  warning: (title: string, message?: string) => void;
  info: (title: string, message?: string) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return context;
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== id));
  }, []);

  const addToast = useCallback(
    (toast: Omit<Toast, "id">) => {
      const id = Math.random().toString(36).substring(2, 9);
      const duration = toast.duration ?? 5000;

      setToasts((prev) => [...prev, { ...toast, id }]);

      if (duration > 0) {
        setTimeout(() => removeToast(id), duration);
      }
    },
    [removeToast]
  );

  const success = useCallback(
    (title: string, message?: string) => {
      addToast({ type: "success", title, message });
    },
    [addToast]
  );

  const error = useCallback(
    (title: string, message?: string) => {
      addToast({ type: "error", title, message, duration: 8000 });
    },
    [addToast]
  );

  const warning = useCallback(
    (title: string, message?: string) => {
      addToast({ type: "warning", title, message });
    },
    [addToast]
  );

  const info = useCallback(
    (title: string, message?: string) => {
      addToast({ type: "info", title, message });
    },
    [addToast]
  );

  return (
    <ToastContext.Provider
      value={{ toasts, addToast, removeToast, success, error, warning, info }}
    >
      {children}
      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </ToastContext.Provider>
  );
}

function ToastContainer({
  toasts,
  removeToast,
}: {
  toasts: Toast[];
  removeToast: (id: string) => void;
}) {
  return (
    <div className="fixed bottom-4 right-4 z-[100] flex flex-col gap-2 pointer-events-none">
      <AnimatePresence mode="popLayout">
        {toasts.map((toast) => (
          <ToastItem key={toast.id} toast={toast} onClose={() => removeToast(toast.id)} />
        ))}
      </AnimatePresence>
    </div>
  );
}

const toastIcons = {
  success: CheckCircle,
  error: XCircle,
  warning: AlertTriangle,
  info: Info,
};

const toastStyles = {
  success: {
    bg: "bg-neon-green/10",
    border: "border-neon-green/30",
    icon: "text-neon-green",
  },
  error: {
    bg: "bg-red-500/10",
    border: "border-red-500/30",
    icon: "text-red-400",
  },
  warning: {
    bg: "bg-yellow-500/10",
    border: "border-yellow-500/30",
    icon: "text-yellow-400",
  },
  info: {
    bg: "bg-neon-cyan/10",
    border: "border-neon-cyan/30",
    icon: "text-neon-cyan",
  },
};

function ToastItem({ toast, onClose }: { toast: Toast; onClose: () => void }) {
  const Icon = toastIcons[toast.type];
  const styles = toastStyles[toast.type];

  return (
    <motion.div
      layout
      initial={{ opacity: 0, x: 100, scale: 0.9 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      exit={{ opacity: 0, x: 100, scale: 0.9 }}
      transition={{ type: "spring", stiffness: 500, damping: 40 }}
      className={cn(
        "pointer-events-auto w-80 max-w-[calc(100vw-2rem)] rounded-xl border backdrop-blur-xl p-4 shadow-xl",
        styles.bg,
        styles.border
      )}
    >
      <div className="flex items-start gap-3">
        <Icon className={cn("w-5 h-5 mt-0.5 shrink-0", styles.icon)} />
        <div className="flex-1 min-w-0">
          <p className="font-medium text-white">{toast.title}</p>
          {toast.message && (
            <p className="text-sm text-slate-400 mt-1">{toast.message}</p>
          )}
        </div>
        <button
          onClick={onClose}
          className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-white/10 transition-colors shrink-0"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </motion.div>
  );
}

// Helper to parse common blockchain errors
export function parseError(error: unknown): string {
  const errorString = String(error);

  // User rejected
  if (errorString.includes("User rejected") || errorString.includes("user rejected")) {
    return "Transaction cancelled by user";
  }

  // Insufficient funds
  if (errorString.includes("insufficient funds") || errorString.includes("InsufficientBalance")) {
    return "Insufficient balance for this transaction";
  }

  // Insufficient allowance
  if (errorString.includes("insufficient allowance") || errorString.includes("InsufficientAllowance")) {
    return "Please approve USDC first";
  }

  // Margin too low
  if (errorString.includes("InsufficientMargin") || errorString.includes("margin")) {
    return "Margin amount is too low (minimum 10% of notional)";
  }

  // Settlement not ready
  if (errorString.includes("SettlementNotReady") || errorString.includes("not ready")) {
    return "Settlement interval not reached yet";
  }

  // Position not active
  if (errorString.includes("PositionNotActive") || errorString.includes("not active")) {
    return "This position is no longer active";
  }

  // Not mature
  if (errorString.includes("NotMature") || errorString.includes("not mature")) {
    return "Position has not reached maturity yet";
  }

  // Gas estimation failed
  if (errorString.includes("gas") || errorString.includes("execution reverted")) {
    return "Transaction would fail - check your inputs";
  }

  // Generic fallback
  if (errorString.length > 100) {
    return "Transaction failed. Please try again.";
  }

  return errorString;
}

// Standalone toast notification (without context)
export function ToastNotification({
  type,
  title,
  message,
  onClose,
  className,
}: {
  type: ToastType;
  title: string;
  message?: string;
  onClose?: () => void;
  className?: string;
}) {
  const Icon = toastIcons[type];
  const styles = toastStyles[type];

  return (
    <div
      className={cn(
        "rounded-xl border backdrop-blur-xl p-4",
        styles.bg,
        styles.border,
        className
      )}
    >
      <div className="flex items-start gap-3">
        <Icon className={cn("w-5 h-5 mt-0.5 shrink-0", styles.icon)} />
        <div className="flex-1 min-w-0">
          <p className="font-medium text-white">{title}</p>
          {message && <p className="text-sm text-slate-400 mt-1">{message}</p>}
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-white/10 transition-colors shrink-0"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
    </div>
  );
}
