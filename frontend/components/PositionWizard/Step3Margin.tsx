"use client";

import { useMemo } from "react";

interface Props {
  notional: string;
  margin: string;
  onNotionalChange: (value: string) => void;
  onMarginChange: (value: string) => void;
}

const PRESET_NOTIONALS = [
  { value: "1000", label: "$1K" },
  { value: "5000", label: "$5K" },
  { value: "10000", label: "$10K" },
  { value: "50000", label: "$50K" },
  { value: "100000", label: "$100K" },
];

export function Step3Margin({
  notional,
  margin,
  onNotionalChange,
  onMarginChange,
}: Props) {
  const notionalNum = parseFloat(notional) || 0;
  const marginNum = parseFloat(margin) || 0;
  const minMargin = notionalNum * 0.1;
  const maxLeverage = 10;

  const leverage = useMemo(() => {
    if (marginNum <= 0) return 0;
    return notionalNum / marginNum;
  }, [notionalNum, marginNum]);

  const leverageColor = useMemo(() => {
    if (leverage <= 3) return "text-green-600 dark:text-green-400";
    if (leverage <= 7) return "text-yellow-600 dark:text-yellow-400";
    return "text-red-600 dark:text-red-400";
  }, [leverage]);

  const marginValid = marginNum >= minMargin;

  // Calculate margin presets based on notional
  const marginPresets = useMemo(() => {
    return [
      { percent: 10, value: (notionalNum * 0.1).toFixed(0), label: "10% (Max Leverage)" },
      { percent: 15, value: (notionalNum * 0.15).toFixed(0), label: "15%" },
      { percent: 20, value: (notionalNum * 0.2).toFixed(0), label: "20%" },
      { percent: 50, value: (notionalNum * 0.5).toFixed(0), label: "50%" },
    ];
  }, [notionalNum]);

  return (
    <div className="space-y-6 font-mono">
      <div className="mb-6">
        <div className="border border-[--terminal-green-dark] p-4 bg-[--bg-secondary]">
          <div className="text-sm text-[--text-comment] mb-2">$ set POSITION_SIZE</div>
          <h3 className="text-lg font-bold text-[--terminal-green] mb-2 uppercase tracking-wider">
            Position Size & Margin
          </h3>
          <div className="text-sm text-[--text-comment]">
            Configure size and collateral
          </div>
        </div>
      </div>

      {/* Notional Amount */}
      <div>
        <label className="block text-sm font-bold text-[--text-secondary] mb-2 uppercase tracking-wide">
          $ Notional Amount (USDC)
        </label>
        <input
          type="number"
          min="100"
          value={notional}
          onChange={(e) => onNotionalChange(e.target.value)}
          className="terminal-input w-full px-4 py-3 min-h-[48px] text-base"
          placeholder="10000"
        />
        <div className="flex flex-wrap gap-2 mt-2">
          {PRESET_NOTIONALS.map((preset) => (
            <button
              key={preset.value}
              type="button"
              onClick={() => onNotionalChange(preset.value)}
              className={`px-3 py-1 text-xs border transition ${
                notional === preset.value
                  ? "border-[--terminal-green] bg-[--terminal-green] text-black"
                  : "border-[--terminal-green-dark] bg-black text-[--text-comment] hover:border-[--terminal-green-dim] hover:text-[--text-secondary]"
              }`}
            >
              {preset.label}
            </button>
          ))}
        </div>
      </div>

      {/* Margin Amount */}
      <div>
        <label className="block text-sm font-bold text-[--text-secondary] mb-2 uppercase tracking-wide">
          $ Margin / Collateral (USDC)
        </label>
        <input
          type="number"
          min="1"
          value={margin}
          onChange={(e) => onMarginChange(e.target.value)}
          className={`terminal-input w-full px-4 py-3 min-h-[48px] text-base ${
            !marginValid ? "border-[--terminal-red]" : ""
          }`}
          placeholder="1000"
        />
        {!marginValid && (
          <p className="text-xs text-[--terminal-red] mt-1 status-error">
            Minimum margin: ${minMargin.toLocaleString()} (10% of notional)
          </p>
        )}
        <div className="flex flex-wrap gap-2 mt-2">
          {marginPresets.map((preset) => (
            <button
              key={preset.percent}
              type="button"
              onClick={() => onMarginChange(preset.value)}
              className={`px-3 py-1 text-xs border transition ${
                margin === preset.value
                  ? "border-[--terminal-green] bg-[--terminal-green] text-black"
                  : "border-[--terminal-green-dark] bg-black text-[--text-comment] hover:border-[--terminal-green-dim] hover:text-[--text-secondary]"
              }`}
            >
              {preset.label}
            </button>
          ))}
        </div>
      </div>

      {/* Leverage Display */}
      <div className="border-2 border-[--terminal-green-dark] bg-[--bg-secondary] p-4">
        <div className="flex justify-between items-center mb-3">
          <span className="text-sm text-[--text-secondary] uppercase tracking-wide">$ leverage</span>
          <span className={`text-xl font-bold ${leverageColor}`}>
            {leverage.toFixed(1)}x
          </span>
        </div>

        {/* Terminal Leverage bar */}
        <div className="relative h-4 border border-[--terminal-green-dark] bg-black overflow-hidden">
          <div
            className={`absolute left-0 top-0 h-full transition-all duration-300 ${
              leverage <= 3
                ? "bg-[--terminal-green]"
                : leverage <= 7
                ? "bg-[--terminal-amber]"
                : "bg-[--terminal-red]"
            }`}
            style={{ width: `${Math.min((leverage / maxLeverage) * 100, 100)}%` }}
          />
          {/* ASCII fill */}
          <div className="absolute inset-0 flex items-center text-xs px-1 font-bold">
            {Array.from({ length: Math.floor((leverage / maxLeverage) * 20) }, () => '█').join('')}
          </div>
        </div>

        <div className="flex justify-between text-xs text-[--text-comment] mt-1">
          <span>1x</span>
          <span>5x</span>
          <span className="text-[--terminal-red]">10x [MAX]</span>
        </div>

        {/* Risk warning */}
        {leverage > 7 && (
          <div className="mt-3 p-2 border border-[--terminal-red] bg-black text-xs text-[--terminal-red] status-warning">
            High leverage increases liquidation risk. Consider adding more margin.
          </div>
        )}
      </div>

      {/* Summary */}
      <div className="border-2 border-[--terminal-green] bg-[--bg-secondary] p-4 space-y-2">
        <div className="text-xs text-[--text-comment] mb-2">$ cat POSITION_SUMMARY.txt</div>
        <div className="flex justify-between text-sm">
          <span className="text-[--text-comment]">position_size:</span>
          <span className="font-bold text-[--terminal-green]">${Number(notional).toLocaleString()}</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-[--text-comment]">required_margin:</span>
          <span className="font-bold text-[--terminal-green]">${Number(margin).toLocaleString()}</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-[--text-comment]">maintenance (5%):</span>
          <span className="font-bold text-[--text-secondary]">${(notionalNum * 0.05).toLocaleString()}</span>
        </div>
      </div>
    </div>
  );
}
