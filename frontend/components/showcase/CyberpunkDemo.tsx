export function CyberpunkDemo() {
  return (
    <div className="min-h-screen bg-black p-8 relative overflow-hidden">
      {/* Animated Grid Background */}
      <div
        className="absolute inset-0 opacity-20"
        style={{
          backgroundImage: `
            linear-gradient(rgba(0, 245, 255, 0.3) 1px, transparent 1px),
            linear-gradient(90deg, rgba(0, 245, 255, 0.3) 1px, transparent 1px)
          `,
          backgroundSize: '50px 50px',
        }}
      />

      {/* Scanlines Effect */}
      <div
        className="absolute inset-0 opacity-10 pointer-events-none"
        style={{
          background: 'repeating-linear-gradient(0deg, rgba(0, 0, 0, 0.15) 0px, transparent 1px, transparent 2px)',
        }}
      />

      <div className="relative z-10 max-w-6xl mx-auto">
        {/* Glitch Header */}
        <div className="text-center mb-12">
          <div className="inline-block relative">
            <h1 className="text-6xl font-black text-[#00F5FF] mb-2 tracking-wider filter drop-shadow-[0_0_10px_rgba(0,245,255,0.8)]">
              BANK_OF_MANTLE
            </h1>
            <div className="absolute inset-0 text-6xl font-black text-[#FF00FF] opacity-70 mix-blend-screen animate-pulse">
              BANK_OF_MANTLE
            </div>
          </div>
          <p className="text-[#FF00FF] text-lg tracking-[0.3em] uppercase">▓▒░ PREMIUM FINANCIAL SERVICES ░▒▓</p>
        </div>

        {/* Terminal-style Cards */}
        <div className="grid md:grid-cols-2 gap-6 mb-8">
          {/* Position Terminal */}
          <div className="border-2 border-[#00F5FF] bg-black/80 shadow-[0_0_30px_rgba(0,245,255,0.3)] relative overflow-hidden">
            {/* Terminal Header */}
            <div className="bg-[#00F5FF] text-black px-4 py-2 font-mono text-sm font-bold flex items-center gap-2">
              <span>█</span>
              POSITION_0x1337.sys
            </div>

            {/* Scanning Line Animation */}
            <div className="absolute top-10 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#00F5FF] to-transparent animate-pulse" />

            <div className="p-6 font-mono">
              <div className="space-y-3 text-[#00F5FF]">
                <div className="flex justify-between border-b border-[#00F5FF]/30 pb-2">
                  <span className="text-gray-400">&gt; STATUS</span>
                  <span className="text-[#39FF14] font-bold animate-pulse">[ACTIVE]</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">&gt; TYPE</span>
                  <span>PAY_FIXED</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">&gt; NOTIONAL</span>
                  <span>10000.00_USDC</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">&gt; RATE</span>
                  <span className="text-[#FFFF00]">6.50%</span>
                </div>
                <div className="flex justify-between border-t border-[#00F5FF]/30 pt-2">
                  <span className="text-gray-400">&gt; PNL</span>
                  <span className="text-[#39FF14] font-bold text-lg">+523.42_USDC</span>
                </div>
              </div>

              <button className="w-full mt-6 py-3 border-2 border-[#FF00FF] bg-transparent text-[#FF00FF] font-bold hover:bg-[#FF00FF] hover:text-black transition-all uppercase tracking-wider shadow-[0_0_20px_rgba(255,0,255,0.5)]">
                &gt; EXECUTE_TRADE
              </button>
            </div>
          </div>

          {/* Stats Panel */}
          <div className="border-2 border-[#FF00FF] bg-black/80 shadow-[0_0_30px_rgba(255,0,255,0.3)]">
            <div className="bg-[#FF00FF] text-black px-4 py-2 font-mono text-sm font-bold">
              █ SYSTEM_STATS.dat
            </div>
            <div className="p-6 font-mono">
              <div className="space-y-6">
                <div>
                  <div className="text-xs text-gray-400 mb-1">&gt; TVL_DATA</div>
                  <div className="text-3xl font-bold text-[#00F5FF]">$1,234,567</div>
                  <div className="h-2 bg-gray-800 rounded mt-2 overflow-hidden">
                    <div className="h-full w-3/4 bg-gradient-to-r from-[#00F5FF] to-[#FF00FF] animate-pulse" />
                  </div>
                </div>

                <div>
                  <div className="text-xs text-gray-400 mb-1">&gt; PNL_TOTAL</div>
                  <div className="text-3xl font-bold text-[#39FF14]">+$12,345</div>
                </div>

                <div>
                  <div className="text-xs text-gray-400 mb-1">&gt; ACTIVE_POSITIONS</div>
                  <div className="text-3xl font-bold text-[#FFFF00]">08</div>
                </div>

                <div className="text-xs text-[#00F5FF] space-y-1 pt-4 border-t border-gray-700">
                  <div>&gt; SYSTEM_ONLINE</div>
                  <div>&gt; LATENCY: 12ms</div>
                  <div className="flex items-center gap-2">
                    <span>&gt; STATUS:</span>
                    <span className="text-[#39FF14] animate-pulse">█ OPERATIONAL</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Hexagonal Feature Grid */}
        <div className="grid grid-cols-4 gap-6">
          {[
            { label: "SECURE", value: "AES-256", color: "#00F5FF" },
            { label: "SPEED", value: "<100ms", color: "#FF00FF" },
            { label: "UPTIME", value: "99.9%", color: "#39FF14" },
            { label: "NODES", value: "1337", color: "#FFFF00" },
          ].map((stat) => (
            <div
              key={stat.label}
              className="border border-gray-700 bg-black/60 p-4 text-center font-mono hover:border-[#00F5FF] transition-all"
              style={{
                boxShadow: `0 0 20px rgba(0, 245, 255, 0.1)`,
              }}
            >
              <div className="text-xs text-gray-400 mb-1">{stat.label}</div>
              <div className="text-xl font-bold" style={{ color: stat.color }}>
                {stat.value}
              </div>
            </div>
          ))}
        </div>

        {/* Command Line */}
        <div className="mt-8 border border-[#00F5FF] bg-black p-4 font-mono text-[#00F5FF]">
          <span className="text-gray-500">user@mantle:~$</span> status --verbose
          <div className="text-xs text-gray-400 mt-2 space-y-1">
            <div>[OK] All systems operational</div>
            <div>[OK] Smart contracts verified</div>
            <div>[OK] Oracle feeds synchronized</div>
            <div className="text-[#39FF14]">[READY] Awaiting user input_█</div>
          </div>
        </div>
      </div>
    </div>
  );
}
