"use client";

import { useReadContract } from "wagmi";
import { formatUnits } from "viem";
import { POSITION_MANAGER_ABI, RATE_ORACLE_ABI } from "@/lib/abis";

interface Props {
  contracts: {
    positionManager: `0x${string}`;
    rateOracle: `0x${string}`;
  };
}

export function ProtocolStats({ contracts }: Props) {
  const { data: totalMargin } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "totalMargin",
  });

  const { data: activePositions } = useReadContract({
    address: contracts.positionManager,
    abi: POSITION_MANAGER_ABI,
    functionName: "activePositionCount",
  });

  const { data: currentRate } = useReadContract({
    address: contracts.rateOracle,
    abi: RATE_ORACLE_ABI,
    functionName: "getCurrentRate",
  });

  const formatUSDC = (value: bigint | undefined) => {
    if (!value) return "$0";
    return `$${Number(formatUnits(value, 6)).toLocaleString()}`;
  };

  const formatRate = (value: bigint | undefined) => {
    if (!value) return "0.00%";
    return `${(Number(formatUnits(value, 18)) * 100).toFixed(2)}%`;
  };

  return (
    <div className="terminal-window font-mono">
      <div className="terminal-header">
        PROTOCOL_STATS.sh
      </div>

      <div className="p-4 sm:p-6 space-y-6">
        {/* Current Rate */}
        <div className="border-2 border-[--terminal-green] bg-[--bg-secondary] p-4 shadow-[0_0_15px_rgba(0,255,65,0.3)]">
          <div className="text-xs text-[--text-comment] mb-1">$ floating_rate</div>
          <div className="text-2xl sm:text-3xl font-bold text-[--terminal-green]">{formatRate(currentRate)}</div>
          <div className="text-xs text-[--text-comment] mt-1">
            [LIVE] Aggregated from lending protocols
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
          <div className="border border-[--terminal-green-dark] bg-black p-4">
            <div className="text-xs text-[--text-comment] uppercase tracking-wide">total_margin</div>
            <div className="text-lg sm:text-xl font-bold text-[--terminal-green]">{formatUSDC(totalMargin)}</div>
          </div>
          <div className="border border-[--terminal-green-dark] bg-black p-4">
            <div className="text-xs text-[--text-comment] uppercase tracking-wide">active_positions</div>
            <div className="text-lg sm:text-xl font-bold text-[--terminal-green]">
              {activePositions?.toString() || 0}
            </div>
          </div>
        </div>

        {/* Key Parameters */}
        <div className="space-y-3">
          <div className="text-xs text-[--text-comment] mb-2">$ cat PARAMETERS.txt</div>
          <div className="border border-[--terminal-green-dark] bg-black p-3 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-[--text-comment]">initial_margin:</span>
              <span className="text-[--terminal-green]">10%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[--text-comment]">maintenance_margin:</span>
              <span className="text-[--terminal-green]">5%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[--text-comment]">max_leverage:</span>
              <span className="text-[--terminal-amber]">10x</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[--text-comment]">liquidation_bonus:</span>
              <span className="text-[--terminal-green]">5%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[--text-comment]">settlement_interval:</span>
              <span className="text-[--terminal-green]">1 day</span>
            </div>
          </div>
        </div>

        {/* Maturities */}
        <div className="space-y-3">
          <div className="text-xs text-[--text-comment]">$ ls MATURITIES/</div>
          <div className="flex flex-wrap gap-2">
            {[30, 90, 180, 365].map((days) => (
              <span
                key={days}
                className="border border-[--terminal-green-dark] bg-black px-3 py-1 text-sm text-[--terminal-green]"
              >
                {days}d
              </span>
            ))}
          </div>
        </div>

        {/* Links */}
        <div className="pt-4 border-t border-[--terminal-green-dark] space-y-2 text-sm">
          <div className="text-[--text-comment]">$ explorer --links</div>
          <a
            href="#"
            className="block text-[--terminal-green] hover:text-[--text-secondary] status-info"
          >
            View on Explorer
          </a>
          <a
            href="https://github.com"
            className="block text-[--text-secondary] hover:text-[--terminal-green] status-info"
          >
            GitHub Repository
          </a>
        </div>
      </div>
    </div>
  );
}
