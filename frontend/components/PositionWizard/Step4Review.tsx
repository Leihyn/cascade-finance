"use client";

import { useMemo } from "react";
import { RateComparison } from "../RateComparison";

interface Props {
  isPayingFixed: boolean;
  notional: string;
  fixedRate: string;
  maturityDays: string;
  margin: string;
  currentFloatingRate: number;
  errors: string[];
}

export function Step4Review({
  isPayingFixed,
  notional,
  fixedRate,
  maturityDays,
  margin,
  currentFloatingRate,
  errors,
}: Props) {
  const notionalNum = parseFloat(notional) || 0;
  const marginNum = parseFloat(margin) || 0;
  const fixedRateNum = parseFloat(fixedRate) || 0;
  const maturityDaysNum = parseInt(maturityDays) || 0;

  const leverage = useMemo(() => {
    if (marginNum <= 0) return 0;
    return notionalNum / marginNum;
  }, [notionalNum, marginNum]);

  const maturityDate = useMemo(() => {
    const date = new Date();
    date.setDate(date.getDate() + maturityDaysNum);
    return date.toLocaleDateString();
  }, [maturityDaysNum]);

  const rateDirection = useMemo(() => {
    if (isPayingFixed) {
      return currentFloatingRate > fixedRateNum ? "favorable" : "unfavorable";
    } else {
      return currentFloatingRate < fixedRateNum ? "favorable" : "unfavorable";
    }
  }, [isPayingFixed, currentFloatingRate, fixedRateNum]);

  return (
    <div className="space-y-6 font-mono">
      <div className="mb-6">
        <div className="border border-[--terminal-green-dark] p-4 bg-[--bg-secondary]">
          <div className="text-sm text-[--text-comment] mb-2">$ review POSITION</div>
          <h3 className="text-lg font-bold text-[--terminal-green] mb-2 uppercase tracking-wider">
            Review Your Position
          </h3>
          <div className="text-sm text-[--text-comment]">
            Verify all parameters before execution
          </div>
        </div>
      </div>

      {/* Errors */}
      {errors.length > 0 && (
        <div className="border-2 border-[--terminal-red] bg-black p-4">
          <h4 className="text-sm font-bold text-[--terminal-red] mb-2 status-error">
            Error: Validation Failed
          </h4>
          <div className="text-sm text-[--terminal-red] space-y-1">
            {errors.map((error, i) => (
              <div key={i} className="status-error">{error}</div>
            ))}
          </div>
        </div>
      )}

      {/* Position Summary Card */}
      <div className="border-2 border-[--terminal-green] bg-[--bg-secondary]">
        {/* Terminal Header */}
        <div className="bg-[--terminal-green] text-black p-4">
          <div className="flex items-center justify-between font-bold">
            <div>
              <div className="text-xs opacity-70 uppercase">Type</div>
              <div className="text-xl">
                {isPayingFixed ? "PAY FIXED {▲}" : "PAY FLOAT {▼}"}
              </div>
            </div>
            <div className="text-right">
              <div className="text-xs opacity-70 uppercase">Leverage</div>
              <div className="text-xl">{leverage.toFixed(1)}x</div>
            </div>
          </div>
        </div>

        {/* Details */}
        <div className="p-4 space-y-4">
          {/* ASCII Divider */}
          <div className="text-[--terminal-green-dark]">╔══════════════════════════════════════╗</div>

          {/* Rates */}
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-xs text-[--text-comment] mb-1 uppercase">You Pay:</div>
              <div className="font-bold text-[--terminal-amber]">
                {isPayingFixed ? `${fixedRateNum.toFixed(2)}%` : `${currentFloatingRate.toFixed(2)}%`}
                <span className="text-xs text-[--text-comment] ml-1">
                  {isPayingFixed ? "[FIX]" : "[FLT]"}
                </span>
              </div>
            </div>
            <div>
              <div className="text-xs text-[--text-comment] mb-1 uppercase">You Receive:</div>
              <div className="font-bold text-[--terminal-green]">
                {isPayingFixed ? `${currentFloatingRate.toFixed(2)}%` : `${fixedRateNum.toFixed(2)}%`}
                <span className="text-xs text-[--text-comment] ml-1">
                  {isPayingFixed ? "[FLT]" : "[FIX]"}
                </span>
              </div>
            </div>
          </div>

          <div className="text-[--terminal-green-dark]">╠══════════════════════════════════════╣</div>

          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-xs text-[--text-comment] mb-1">notional:</div>
              <div className="font-bold text-[--terminal-green]">${notionalNum.toLocaleString()}</div>
            </div>
            <div>
              <div className="text-xs text-[--text-comment] mb-1">margin:</div>
              <div className="font-bold text-[--terminal-green]">${marginNum.toLocaleString()}</div>
            </div>
            <div>
              <div className="text-xs text-[--text-comment] mb-1">duration:</div>
              <div className="font-bold text-[--text-secondary]">{maturityDaysNum}d</div>
            </div>
            <div>
              <div className="text-xs text-[--text-comment] mb-1">maturity:</div>
              <div className="font-bold text-[--text-secondary]">{maturityDate}</div>
            </div>
          </div>

          <div className="text-[--terminal-green-dark]">╚══════════════════════════════════════╝</div>

          {/* Market Outlook */}
          <div
            className={`p-3 border-2 ${
              rateDirection === "favorable"
                ? "border-[--terminal-green] bg-black"
                : "border-[--terminal-amber] bg-black"
            }`}
          >
            <div className="flex items-center gap-2">
              <span
                className={`text-lg font-bold ${
                  rateDirection === "favorable" ? "text-[--terminal-green]" : "text-[--terminal-amber]"
                }`}
              >
                {rateDirection === "favorable" ? "[✓]" : "[!]"}
              </span>
              <div>
                <div
                  className={`text-sm font-bold uppercase ${
                    rateDirection === "favorable"
                      ? "text-[--terminal-green]"
                      : "text-[--terminal-amber]"
                  }`}
                >
                  {rateDirection === "favorable" ? "Currently Favorable" : "Currently Unfavorable"}
                </div>
                <div className="text-xs text-[--text-comment]">
                  {isPayingFixed
                    ? "Floating rate is " +
                      (currentFloatingRate > fixedRateNum ? "above" : "below") +
                      " your fixed rate"
                    : "Floating rate is " +
                      (currentFloatingRate < fixedRateNum ? "below" : "above") +
                      " your fixed rate"}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Rate Analysis */}
      <RateComparison
        currentFloatingRate={currentFloatingRate}
        fixedRate={fixedRateNum}
        notional={notionalNum}
        maturityDays={maturityDaysNum}
        isPayingFixed={isPayingFixed}
      />

      {/* Disclaimer */}
      <div className="text-xs text-[--text-comment] text-center border border-[--terminal-green-dark] p-3 bg-black">
        <div className="status-warning inline-block mb-1">RISK DISCLOSURE</div>
        <div>
          By executing this position, you agree to protocol terms. Positions may be liquidated if margin falls below maintenance requirements.
        </div>
      </div>
    </div>
  );
}
