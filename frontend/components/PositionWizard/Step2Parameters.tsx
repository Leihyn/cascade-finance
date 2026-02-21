"use client";

import { RateComparison } from "../RateComparison";

interface Props {
  isPayingFixed: boolean;
  fixedRate: string;
  maturityDays: string;
  currentFloatingRate: number;
  onFixedRateChange: (value: string) => void;
  onMaturityChange: (value: string) => void;
  notional: string;
}

const MATURITY_OPTIONS = [
  { value: "30", label: "30 Days", description: "1 month" },
  { value: "90", label: "90 Days", description: "3 months" },
  { value: "180", label: "180 Days", description: "6 months" },
  { value: "365", label: "365 Days", description: "1 year" },
];

export function Step2Parameters({
  isPayingFixed,
  fixedRate,
  maturityDays,
  currentFloatingRate,
  onFixedRateChange,
  onMaturityChange,
  notional,
}: Props) {
  return (
    <div className="space-y-6 font-mono">
      <div className="mb-6">
        <div className="border border-[--terminal-green-dark] p-4 bg-[--bg-secondary]">
          <div className="text-sm text-[--text-comment] mb-2">$ configure TERMS</div>
          <h3 className="text-lg font-bold text-[--terminal-green] mb-2 uppercase tracking-wider">
            Set Your Terms
          </h3>
          <div className="text-sm text-[--text-comment]">
            Configure fixed rate and maturity
          </div>
        </div>
      </div>

      {/* Fixed Rate Input */}
      <div>
        <label className="block text-sm font-bold text-[--text-secondary] mb-2 uppercase tracking-wide">
          $ Fixed Rate (%)
        </label>
        <div className="relative">
          <input
            type="number"
            step="0.1"
            min="0"
            max="100"
            value={fixedRate}
            onChange={(e) => onFixedRateChange(e.target.value)}
            className="terminal-input w-full px-4 py-3 min-h-[48px] text-base"
            placeholder="5.0"
          />
          <span className="absolute right-4 top-1/2 -translate-y-1/2 text-[--text-comment]">%</span>
        </div>
        <div className="mt-2 flex items-center gap-2 text-xs">
          <span className="text-[--text-comment]">
            floating: {currentFloatingRate.toFixed(2)}%
          </span>
          <button
            type="button"
            onClick={() => onFixedRateChange(currentFloatingRate.toFixed(2))}
            className="text-[--terminal-green] hover:text-[--text-secondary] bg-transparent border-0 p-0 font-bold uppercase text-xs"
            style={{ all: 'unset', cursor: 'pointer', color: 'var(--terminal-green)', fontSize: '11px', fontWeight: 700 }}
          >
            [MATCH]
          </button>
        </div>
      </div>

      {/* Maturity Selection */}
      <div>
        <label className="block text-sm font-bold text-[--text-secondary] mb-2 uppercase tracking-wide">
          $ Contract Duration
        </label>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          {MATURITY_OPTIONS.map((option) => (
            <button
              key={option.value}
              type="button"
              onClick={() => onMaturityChange(option.value)}
              className={`p-3 border-2 transition text-center ${
                maturityDays === option.value
                  ? "border-[--terminal-green] bg-[--bg-secondary] shadow-[0_0_10px_rgba(0,255,65,0.3)]"
                  : "border-[--terminal-green-dark] bg-black hover:border-[--terminal-green-dim]"
              }`}
            >
              <div
                className={`font-bold text-sm ${
                  maturityDays === option.value
                    ? "text-[--terminal-green]"
                    : "text-[--text-secondary]"
                }`}
              >
                {option.label}
              </div>
              <div className="text-xs text-[--text-comment]">
                {option.description}
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Rate Comparison Preview */}
      <div className="mt-6">
        <RateComparison
          currentFloatingRate={currentFloatingRate}
          fixedRate={parseFloat(fixedRate) || 0}
          notional={parseFloat(notional) || 10000}
          maturityDays={parseInt(maturityDays) || 90}
          isPayingFixed={isPayingFixed}
        />
      </div>
    </div>
  );
}
