export function ClassicBankingDemo() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0A1628] via-[#0F1F3A] to-[#162844] p-8">
      {/* Hero Section */}
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-3 mb-4">
            <div className="w-16 h-16 rounded-xl bg-gradient-to-br from-[#D4AF37] to-[#C19A2E] flex items-center justify-center shadow-2xl">
              <span className="text-3xl">🏦</span>
            </div>
            <h1 className="text-5xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[#D4AF37] to-[#F4E5B8]">
              CASCADE FINANCE
            </h1>
          </div>
          <p className="text-xl text-gray-300">Premium Financial Services</p>
        </div>

        {/* Cards Grid */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          {/* Position Card */}
          <div className="bg-white/5 backdrop-blur-xl border border-[#D4AF37]/30 rounded-2xl p-6 hover:border-[#D4AF37]/50 transition-all hover:shadow-[0_0_30px_rgba(212,175,55,0.2)]">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-white">Position #1234</h3>
              <span className="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-sm font-medium">
                Active
              </span>
            </div>
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-gray-400">Type</span>
                <span className="text-white font-medium">Pay Fixed</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Notional</span>
                <span className="text-white font-medium">10,000 USDC</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Fixed Rate</span>
                <span className="text-[#D4AF37] font-medium">6.50%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">PnL</span>
                <span className="text-green-400 font-bold">+$523.42</span>
              </div>
            </div>
            <button className="w-full mt-6 py-3 bg-gradient-to-r from-[#D4AF37] to-[#C19A2E] text-[#0A1628] rounded-lg font-semibold hover:shadow-lg transition-all">
              Manage Position
            </button>
          </div>

          {/* Stats Card */}
          <div className="bg-white/5 backdrop-blur-xl border border-[#3B82F6]/30 rounded-2xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Portfolio Stats</h3>
            <div className="space-y-4">
              <div>
                <div className="text-sm text-gray-400 mb-1">Total Value Locked</div>
                <div className="text-2xl font-bold text-white">$1,234,567</div>
              </div>
              <div>
                <div className="text-sm text-gray-400 mb-1">Total PnL</div>
                <div className="text-2xl font-bold text-green-400">+$12,345</div>
              </div>
              <div>
                <div className="text-sm text-gray-400 mb-1">Active Positions</div>
                <div className="text-2xl font-bold text-[#D4AF37]">8</div>
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="bg-white/5 backdrop-blur-xl border border-gray-700 rounded-2xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Quick Actions</h3>
            <div className="space-y-3">
              <button className="w-full py-3 bg-[#3B82F6] hover:bg-[#2563EB] text-white rounded-lg font-medium transition-all">
                Open New Position
              </button>
              <button className="w-full py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-all">
                View All Positions
              </button>
              <button className="w-full py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-all">
                Analytics Dashboard
              </button>
            </div>
          </div>
        </div>

        {/* Feature Highlights */}
        <div className="grid md:grid-cols-4 gap-4">
          {[
            { icon: "🛡️", title: "Secure", desc: "Bank-grade security" },
            { icon: "⚡", title: "Fast", desc: "Instant settlements" },
            { icon: "📊", title: "Professional", desc: "Institutional tools" },
            { icon: "🌐", title: "Global", desc: "24/7 trading" },
          ].map((feature) => (
            <div
              key={feature.title}
              className="bg-white/5 backdrop-blur-xl border border-gray-700 rounded-xl p-4 text-center hover:border-[#D4AF37]/50 transition-all"
            >
              <div className="text-3xl mb-2">{feature.icon}</div>
              <div className="font-semibold text-white mb-1">{feature.title}</div>
              <div className="text-sm text-gray-400">{feature.desc}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
