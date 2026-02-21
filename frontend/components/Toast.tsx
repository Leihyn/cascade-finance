"use client";

import { useState, createContext, useContext, ReactNode } from "react";

interface Toast {
  id: string;
  type: "success" | "error" | "info" | "warning";
  message: string;
  duration?: number;
}

interface ToastContextType {
  toasts: Toast[];
  addToast: (toast: Omit<Toast, "id">) => void;
  removeToast: (id: string) => void;
}

const ToastContext = createContext<ToastContextType | undefined>(undefined);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const addToast = (toast: Omit<Toast, "id">) => {
    const id = Math.random().toString(36).substr(2, 9);
    setToasts((prev) => [...prev, { ...toast, id }]);

    // Auto remove after duration
    setTimeout(() => {
      removeToast(id);
    }, toast.duration || 5000);
  };

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  return (
    <ToastContext.Provider value={{ toasts, addToast, removeToast }}>
      {children}
      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return context;
}

function ToastContainer({
  toasts,
  removeToast,
}: {
  toasts: Toast[];
  removeToast: (id: string) => void;
}) {
  const getToastStyle = (type: Toast["type"]) => {
    switch (type) {
      case "success":
        return "bg-green-50 dark:bg-green-900/90 border-green-500 text-green-800 dark:text-green-100";
      case "error":
        return "bg-red-50 dark:bg-red-900/90 border-red-500 text-red-800 dark:text-red-100";
      case "warning":
        return "bg-yellow-50 dark:bg-yellow-900/90 border-yellow-500 text-yellow-800 dark:text-yellow-100";
      case "info":
      default:
        return "bg-blue-50 dark:bg-blue-900/90 border-blue-500 text-blue-800 dark:text-blue-100";
    }
  };

  const getIcon = (type: Toast["type"]) => {
    switch (type) {
      case "success":
        return "✓";
      case "error":
        return "✕";
      case "warning":
        return "⚠";
      case "info":
      default:
        return "ℹ";
    }
  };

  return (
    <div className="fixed bottom-4 left-4 right-4 sm:left-auto sm:right-4 z-50 flex flex-col gap-2 sm:max-w-sm">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`flex items-center gap-3 px-4 py-3 rounded-lg border shadow-lg animate-slide-up ${getToastStyle(
            toast.type
          )}`}
        >
          <span className="text-lg">{getIcon(toast.type)}</span>
          <p className="flex-1 text-sm">{toast.message}</p>
          <button
            onClick={() => removeToast(toast.id)}
            className="text-current opacity-70 hover:opacity-100 min-w-[24px] min-h-[24px]"
            aria-label="Close"
          >
            ×
          </button>
        </div>
      ))}
    </div>
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
