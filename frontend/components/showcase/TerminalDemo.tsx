export function TerminalDemo() {
  return (
    <div className="min-h-screen bg-black p-8 font-mono">
      {/* Scanlines */}
      <div
        className="absolute inset-0 opacity-5 pointer-events-none"
        style={{
          background: 'repeating-linear-gradient(0deg, rgba(0, 255, 65, 0.03) 0px, transparent 1px, transparent 2px)',
        }}
      />

      <div className="max-w-6xl mx-auto relative z-10">
        {/* Terminal Header */}
        <div className="mb-8">
          <div className="text-[#00FF41] text-sm mb-2">
            ┌─[root@mantle]─[~/bank]
          </div>
          <div className="text-[#00FF41] text-4xl font-bold mb-1">
            └──╼ $ ./BANK_OF_MANTLE.sh --start
          </div>
          <div className="text-[#00CC33] text-sm">
            [✓] Initializing premium financial services...
          </div>
        </div>

        {/* Main Terminal Windows Grid */}
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          {/* Position Window */}
          <div className="border-2 border-[#00FF41] bg-black shadow-[0_0_20px_rgba(0,255,65,0.3)]">
            <div className="bg-[#00FF41] text-black px-3 py-1 font-bold text-sm">
              █ POSITION_MANAGER.bin
            </div>
            <div className="p-4 text-[#00FF41] text-sm space-y-2">
              <div>╔════════════════════════════════════╗</div>
              <div>║ POSITION #0x1337                  ║</div>
              <div>╠════════════════════════════════════╣</div>
              <div>║ $ type: PAY_FIXED                 ║</div>
              <div>║ $ notional: 10000.00 USDC         ║</div>
              <div>║ $ fixed_rate: 6.50%               ║</div>
              <div>║ $ maturity: 90 days               ║</div>
              <div>║ $ margin: 1500.00 USDC            ║</div>
              <div>╠════════════════════════════════════╣</div>
              <div>║ $ status: [ACTIVE]                ║</div>
              <div>║ $ pnl: +523.42 USDC (+5.23%)     ║</div>
              <div>╚════════════════════════════════════╝</div>

              <div className="mt-4 pt-4 border-t border-[#00FF41]/30">
                <div className="text-[#00CC33]">$ Available commands:</div>
                <div className="ml-4 text-xs space-y-1 text-[#006622]">
                  <div>  &gt; close_position</div>
                  <div>  &gt; add_margin</div>
                  <div>  &gt; view_history</div>
                </div>
              </div>

              <div className="flex gap-2 mt-4">
                <button className="flex-1 border border-[#00FF41] px-3 py-2 hover:bg-[#00FF41] hover:text-black transition-all">
                  [EXECUTE]
                </button>
                <button className="flex-1 border border-[#00CC33] text-[#00CC33] px-3 py-2 hover:bg-[#00CC33] hover:text-black transition-all">
                  [CANCEL]
                </button>
              </div>
            </div>
          </div>

          {/* System Stats Window */}
          <div className="border-2 border-[#00FF41] bg-black shadow-[0_0_20px_rgba(0,255,65,0.3)]">
            <div className="bg-[#00FF41] text-black px-3 py-1 font-bold text-sm">
              █ SYSTEM_STATUS.log
            </div>
            <div className="p-4 text-[#00FF41] text-sm space-y-3">
              <div>
                <div className="text-[#00CC33]">&gt; total_value_locked</div>
                <div className="text-2xl font-bold">$1,234,567</div>
                <div className="text-xs text-[#006622]">████████████░░░░ 75%</div>
              </div>

              <div>
                <div className="text-[#00CC33]">&gt; portfolio_pnl</div>
                <div className="text-2xl font-bold">+$12,345.00</div>
                <div className="text-xs">ROI: +12.34%</div>
              </div>

              <div>
                <div className="text-[#00CC33]">&gt; active_positions</div>
                <div className="text-2xl font-bold">08</div>
              </div>

              <div className="border-t border-[#00FF41]/30 pt-3 space-y-1 text-xs">
                <div>[✓] NETWORK: Base Sepolia</div>
                <div>[✓] BLOCK: #8,234,567</div>
                <div>[✓] GAS: 12 gwei</div>
                <div>[✓] LATENCY: 23ms</div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-[#00FF41] rounded-full animate-pulse" />
                  <div>ONLINE</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Command Line Interface */}
        <div className="border-2 border-[#00FF41] bg-black shadow-[0_0_20px_rgba(0,255,65,0.3)]">
          <div className="bg-[#00FF41] text-black px-3 py-1 font-bold text-sm">
            █ TERMINAL.sh
          </div>
          <div className="p-4 text-[#00FF41] text-sm">
            <div className="space-y-1">
              <div>
                <span className="text-[#00CC33]">bank@mantle</span>
                <span className="text-white">:</span>
                <span className="text-[#3399FF]">~/positions</span>
                <span className="text-white">$</span> ls -la
              </div>
              <div className="ml-4 text-xs space-y-1">
                <div>drwxr-xr-x 8 root root 4096 Jan 10 18:00 .</div>
                <div>drwxr-xr-x 3 root root 4096 Jan 10 17:00 ..</div>
                <div className="text-[#00CC33]">-rw-r--r-- 1 root root  523 Jan 10 18:00 position_0x1337.dat</div>
                <div className="text-[#00CC33]">-rw-r--r-- 1 root root  892 Jan 10 17:45 position_0x1338.dat</div>
                <div className="text-[#00CC33]">-rw-r--r-- 1 root root 1024 Jan 10 17:30 position_0x1339.dat</div>
              </div>
            </div>

            <div className="mt-4 space-y-1">
              <div>
                <span className="text-[#00CC33]">bank@mantle</span>
                <span className="text-white">:</span>
                <span className="text-[#3399FF]">~/positions</span>
                <span className="text-white">$</span> status --all
              </div>
              <div className="ml-4 text-xs space-y-1 text-[#00CC33]">
                <div>[OK] All positions healthy</div>
                <div>[OK] Margin requirements met</div>
                <div>[OK] Oracle feeds synchronized</div>
                <div>[OK] Settlement engine operational</div>
              </div>
            </div>

            <div className="mt-4">
              <div>
                <span className="text-[#00CC33]">bank@mantle</span>
                <span className="text-white">:</span>
                <span className="text-[#3399FF]">~/positions</span>
                <span className="text-white">$</span> <span className="animate-pulse">█</span>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Status Bar (vim-style) */}
        <div className="mt-6 bg-[#00FF41] text-black px-4 py-2 font-bold text-xs flex justify-between">
          <div>-- NORMAL MODE --</div>
          <div>POSITIONS: 8 | TVL: $1.23M | PNL: +$12.3K</div>
          <div>18:00:00</div>
        </div>
      </div>
    </div>
  );
}
