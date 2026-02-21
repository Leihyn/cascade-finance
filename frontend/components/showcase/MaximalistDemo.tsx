export function MaximalistDemo() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0F0F1E] via-[#1A1A2E] to-[#0F0F1E] p-8 relative overflow-hidden">
      {/* Floating Gradient Orbs */}
      <div className="absolute top-20 left-10 w-96 h-96 bg-purple-500 rounded-full mix-blend-screen filter blur-3xl opacity-20 animate-pulse" />
      <div className="absolute bottom-20 right-10 w-96 h-96 bg-pink-500 rounded-full mix-blend-screen filter blur-3xl opacity-20 animate-pulse" style={{ animationDelay: '1s' }} />
      <div className="absolute top-1/2 left-1/2 w-96 h-96 bg-blue-500 rounded-full mix-blend-screen filter blur-3xl opacity-15 animate-pulse" style={{ animationDelay: '2s' }} />

      <div className="relative z-10 max-w-6xl mx-auto">
        {/* Gradient Header */}
        <div className="text-center mb-12">
          <h1 className="text-6xl font-black mb-4 bg-clip-text text-transparent bg-gradient-to-r from-purple-400 via-pink-400 to-red-400 animate-pulse">
            CASCADE FINANCE
          </h1>
          <p className="text-xl bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-400">
            ✨ Premium Financial Services ✨
          </p>
        </div>

        {/* Glass Morphism Cards */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          {/* Position Card with Animated Border */}
          <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 rounded-2xl blur opacity-75 group-hover:opacity-100 transition duration-1000 animate-pulse" />
            <div className="relative bg-black/40 backdrop-blur-xl border border-white/10 rounded-2xl p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-white">Position #1234</h3>
                <div className="px-3 py-1 bg-gradient-to-r from-green-400 to-emerald-400 text-black rounded-full text-xs font-bold">
                  ACTIVE
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-400">Type</span>
                  <span className="text-white font-semibold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                    Pay Fixed
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Notional</span>
                  <span className="text-white font-semibold">10,000 USDC</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Fixed Rate</span>
                  <span className="text-transparent bg-clip-text bg-gradient-to-r from-yellow-400 to-orange-400 font-bold">
                    6.50%
                  </span>
                </div>
                <div className="pt-3 border-t border-white/10 flex justify-between">
                  <span className="text-gray-400">PnL</span>
                  <span className="text-2xl font-black text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-emerald-400">
                    +$523
                  </span>
                </div>
              </div>

              <button className="w-full mt-6 py-3 bg-gradient-to-r from-purple-500 via-pink-500 to-red-500 text-white rounded-xl font-bold hover:shadow-lg hover:shadow-purple-500/50 transition-all transform hover:scale-105">
                🚀 Manage
              </button>
            </div>
          </div>

          {/* Stats Card with Rainbow Gradient */}
          <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 via-purple-600 to-pink-600 rounded-2xl blur opacity-75 group-hover:opacity-100 transition duration-1000" />
            <div className="relative bg-black/40 backdrop-blur-xl border border-white/10 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-6 flex items-center gap-2">
                <span className="text-2xl">💎</span> Portfolio
              </h3>

              <div className="space-y-6">
                <div>
                  <div className="text-sm text-gray-400 mb-2">Total Value</div>
                  <div className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-400">
                    $1.23M
                  </div>
                  <div className="h-2 bg-gray-800 rounded-full mt-2 overflow-hidden">
                    <div
                      className="h-full bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 rounded-full"
                      style={{ width: "75%", animation: "shimmer 2s infinite" }}
                    />
                  </div>
                </div>

                <div>
                  <div className="text-sm text-gray-400 mb-2">Total PnL</div>
                  <div className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-emerald-400">
                    +$12.3K
                  </div>
                </div>

                <div>
                  <div className="text-sm text-gray-400 mb-2">Active Positions</div>
                  <div className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-yellow-400 to-orange-400">
                    8
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Actions Card */}
          <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-green-600 via-blue-600 to-purple-600 rounded-2xl blur opacity-75 group-hover:opacity-100 transition duration-1000" />
            <div className="relative bg-black/40 backdrop-blur-xl border border-white/10 rounded-2xl p-6">
              <h3 className="text-lg font-bold text-white mb-6">⚡ Quick Actions</h3>

              <div className="space-y-3">
                <button className="w-full py-3 bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-xl font-bold hover:shadow-lg hover:shadow-purple-500/50 transition-all transform hover:scale-105">
                  ✨ Open Position
                </button>
                <button className="w-full py-3 bg-gradient-to-r from-blue-500 to-purple-500 text-white rounded-xl font-bold hover:shadow-lg hover:shadow-blue-500/50 transition-all transform hover:scale-105">
                  📊 View All
                </button>
                <button className="w-full py-3 bg-gradient-to-r from-green-500 to-blue-500 text-white rounded-xl font-bold hover:shadow-lg hover:shadow-green-500/50 transition-all transform hover:scale-105">
                  📈 Analytics
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Animated Feature Grid */}
        <div className="grid grid-cols-4 gap-4">
          {[
            { icon: "🛡️", label: "Secure", gradient: "from-blue-400 to-cyan-400" },
            { icon: "⚡", label: "Fast", gradient: "from-yellow-400 to-orange-400" },
            { icon: "💎", label: "Premium", gradient: "from-purple-400 to-pink-400" },
            { icon: "🌈", label: "Beautiful", gradient: "from-pink-400 to-red-400" },
          ].map((feature) => (
            <div
              key={feature.label}
              className="relative group p-6 bg-black/40 backdrop-blur-xl border border-white/10 rounded-xl text-center hover:scale-110 transition-transform"
            >
              <div className="absolute inset-0 bg-gradient-to-r ${feature.gradient} opacity-0 group-hover:opacity-20 rounded-xl transition-opacity" />
              <div className="relative">
                <div className="text-4xl mb-2">{feature.icon}</div>
                <div className={`font-bold text-transparent bg-clip-text bg-gradient-to-r ${feature.gradient}`}>
                  {feature.label}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <style jsx>{`
        @keyframes shimmer {
          0%, 100% {
            transform: translateX(-100%);
          }
          50% {
            transform: translateX(100%);
          }
        }
      `}</style>
    </div>
  );
}
