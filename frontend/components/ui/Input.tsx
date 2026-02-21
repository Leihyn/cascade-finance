"use client";

import { forwardRef, useState } from "react";
import { Eye, EyeOff, AlertCircle, CheckCircle } from "lucide-react";
import { cn } from "@/lib/utils";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  success?: string;
  hint?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  leftAddon?: React.ReactNode;
  rightAddon?: React.ReactNode;
}

const Input = forwardRef<HTMLInputElement, InputProps>(
  (
    {
      className,
      type = "text",
      label,
      error,
      success,
      hint,
      leftIcon,
      rightIcon,
      leftAddon,
      rightAddon,
      disabled,
      ...props
    },
    ref
  ) => {
    const [showPassword, setShowPassword] = useState(false);
    const isPassword = type === "password";
    const inputType = isPassword ? (showPassword ? "text" : "password") : type;

    const hasError = Boolean(error);
    const hasSuccess = Boolean(success);

    return (
      <div className="w-full">
        {label && (
          <label className="block text-sm font-medium text-slate-300 mb-2">
            {label}
          </label>
        )}

        <div className="relative flex">
          {leftAddon && (
            <div className="flex items-center px-4 bg-dark-800 border border-r-0 border-white/10 rounded-l-xl text-slate-400 text-sm">
              {leftAddon}
            </div>
          )}

          <div className="relative flex-1">
            {leftIcon && (
              <div className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500">
                {leftIcon}
              </div>
            )}

            <input
              ref={ref}
              type={inputType}
              disabled={disabled}
              className={cn(
                "w-full px-4 py-3 bg-dark-800 border rounded-xl text-white placeholder:text-slate-500",
                "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-dark-950 transition-all",
                "disabled:opacity-50 disabled:cursor-not-allowed",
                hasError
                  ? "border-red-500/50 focus:ring-red-500/50 focus:border-red-500"
                  : hasSuccess
                  ? "border-neon-green/50 focus:ring-neon-green/50 focus:border-neon-green"
                  : "border-white/10 focus:ring-neon-cyan/50 focus:border-neon-cyan/50 hover:border-white/20",
                leftIcon && "pl-12",
                (rightIcon || isPassword) && "pr-12",
                leftAddon && "rounded-l-none",
                rightAddon && "rounded-r-none",
                className
              )}
              {...props}
            />

            {(rightIcon || isPassword) && (
              <div className="absolute right-4 top-1/2 -translate-y-1/2">
                {isPassword ? (
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="text-slate-500 hover:text-white transition-colors"
                  >
                    {showPassword ? (
                      <EyeOff className="w-5 h-5" />
                    ) : (
                      <Eye className="w-5 h-5" />
                    )}
                  </button>
                ) : (
                  <div className="text-slate-500">{rightIcon}</div>
                )}
              </div>
            )}
          </div>

          {rightAddon && (
            <div className="flex items-center px-4 bg-dark-800 border border-l-0 border-white/10 rounded-r-xl text-slate-400 text-sm">
              {rightAddon}
            </div>
          )}
        </div>

        {(error || success || hint) && (
          <div className="mt-2 flex items-center gap-1.5 text-sm">
            {hasError && (
              <>
                <AlertCircle className="w-4 h-4 text-red-400" />
                <span className="text-red-400">{error}</span>
              </>
            )}
            {hasSuccess && !hasError && (
              <>
                <CheckCircle className="w-4 h-4 text-neon-green" />
                <span className="text-neon-green">{success}</span>
              </>
            )}
            {hint && !hasError && !hasSuccess && (
              <span className="text-slate-500">{hint}</span>
            )}
          </div>
        )}
      </div>
    );
  }
);

Input.displayName = "Input";

export { Input };

export interface TextAreaProps
  extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  hint?: string;
}

export const TextArea = forwardRef<HTMLTextAreaElement, TextAreaProps>(
  ({ className, label, error, hint, disabled, ...props }, ref) => {
    const hasError = Boolean(error);

    return (
      <div className="w-full">
        {label && (
          <label className="block text-sm font-medium text-slate-300 mb-2">
            {label}
          </label>
        )}

        <textarea
          ref={ref}
          disabled={disabled}
          className={cn(
            "w-full px-4 py-3 bg-dark-800 border rounded-xl text-white placeholder:text-slate-500 resize-none",
            "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-dark-950 transition-all",
            "disabled:opacity-50 disabled:cursor-not-allowed",
            hasError
              ? "border-red-500/50 focus:ring-red-500/50"
              : "border-white/10 focus:ring-neon-cyan/50 focus:border-neon-cyan/50 hover:border-white/20",
            className
          )}
          {...props}
        />

        {(error || hint) && (
          <div className="mt-2 flex items-center gap-1.5 text-sm">
            {hasError ? (
              <>
                <AlertCircle className="w-4 h-4 text-red-400" />
                <span className="text-red-400">{error}</span>
              </>
            ) : (
              <span className="text-slate-500">{hint}</span>
            )}
          </div>
        )}
      </div>
    );
  }
);

TextArea.displayName = "TextArea";

export interface NumberInputProps extends Omit<InputProps, "type" | "onChange"> {
  value: number | string;
  onChange: (value: number | string) => void;
  min?: number;
  max?: number;
  step?: number;
  allowNegative?: boolean;
  suffix?: string;
  prefix?: string;
}

export function NumberInput({
  value,
  onChange,
  min,
  max,
  step = 1,
  allowNegative = false,
  suffix,
  prefix,
  ...props
}: NumberInputProps) {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const inputValue = e.target.value;

    if (inputValue === "" || inputValue === "-") {
      onChange(inputValue);
      return;
    }

    const numValue = parseFloat(inputValue);
    if (isNaN(numValue)) return;

    if (!allowNegative && numValue < 0) return;
    if (min !== undefined && numValue < min) return;
    if (max !== undefined && numValue > max) return;

    onChange(inputValue);
  };

  return (
    <Input
      type="text"
      inputMode="decimal"
      value={value}
      onChange={handleChange}
      leftAddon={prefix}
      rightAddon={suffix}
      {...props}
    />
  );
}
