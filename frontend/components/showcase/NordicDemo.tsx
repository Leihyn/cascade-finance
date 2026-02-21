export function NordicDemo() {
  return (
    <div className="min-h-screen bg-white p-8">
      <div className="max-w-6xl mx-auto">
        {/* Clean Header */}
        <div className="mb-12">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-12 h-12 rounded-2xl bg-blue-500 flex items-center justify-center">
              <span className="text-2xl">🏦</span>
            </div>
            <div>
              <h1 className="text-4xl font-bold text-gray-900">Cascade Finance</h1>
              <p className="text-gray-600">Interest Rate Markets</p>
            </div>
          </div>
        </div>

        {/* Clean Cards */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          {/* Position Card */}
          <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-gray-900">Position #1234</h3>
              <span className="px-3 py-1 bg-green-100 text-green-700 rounded-full text-xs font-medium">
                Active
              </span>
            </div>

            <div className="space-y-4 mb-6">
              <div>
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Type</div>
                <div className="text-gray-900 font-medium">Pay Fixed</div>
              </div>
              <div>
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Notional</div>
                <div className="text-gray-900 font-medium">10,000 USDC</div>
              </div>
              <div>
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Fixed Rate</div>
                <div className="text-blue-600 font-semibold">6.50%</div>
              </div>
              <div className="pt-4 border-t border-gray-100">
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Profit/Loss</div>
                <div className="text-2xl font-bold text-green-600">+$523.42</div>
                <div className="text-sm text-green-600">+5.23%</div>
              </div>
            </div>

            <button className="w-full py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-xl font-medium transition-colors">
              Manage
            </button>
          </div>

          {/* Stats Card */}
          <div className="bg-gray-50 border border-gray-200 rounded-2xl p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-6">Portfolio</h3>

            <div className="space-y-6">
              <div>
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-2">Total Value</div>
                <div className="text-3xl font-bold text-gray-900">$1.23M</div>
              </div>

              <div>
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-2">Total PnL</div>
                <div className="text-3xl font-bold text-green-600">+$12.3K</div>
              </div>

              <div>
                <div className="text-xs text-gray-500 uppercase tracking-wide mb-2">Positions</div>
                <div className="text-3xl font-bold text-blue-600">8</div>
              </div>
            </div>
          </div>

          {/* Actions Card */}
          <div className="bg-white border border-gray-200 rounded-2xl p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-6">Actions</h3>

            <div className="space-y-3">
              <button className="w-full py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-xl font-medium transition-colors">
                Open Position
              </button>
              <button className="w-full py-3 bg-gray-100 hover:bg-gray-200 text-gray-900 rounded-xl font-medium transition-colors">
                View All
              </button>
              <button className="w-full py-3 bg-gray-100 hover:bg-gray-200 text-gray-900 rounded-xl font-medium transition-colors">
                Analytics
              </button>
            </div>
          </div>
        </div>

        {/* Feature Pills */}
        <div className="grid grid-cols-4 gap-4">
          {[
            { icon: "🛡️", label: "Secure" },
            { icon: "⚡", label: "Fast" },
            { icon: "📊", label: "Professional" },
            { icon: "🌐", label: "24/7" },
          ].map((feature) => (
            <div
              key={feature.label}
              className="bg-white border border-gray-200 rounded-xl p-4 text-center hover:border-blue-300 transition-colors"
            >
              <div className="text-3xl mb-2">{feature.icon}</div>
              <div className="text-sm font-medium text-gray-700">{feature.label}</div>
            </div>
          ))}
        </div>

        {/* Clean Table */}
        <div className="mt-8 bg-white border border-gray-200 rounded-2xl overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <h3 className="font-semibold text-gray-900">Recent Activity</h3>
          </div>
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Action</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {[
                { time: "2 min ago", action: "Opened Position", amount: "10,000 USDC", status: "success" },
                { time: "1 hour ago", action: "Closed Position", amount: "5,000 USDC", status: "success" },
                { time: "3 hours ago", action: "Added Margin", amount: "1,000 USDC", status: "success" },
              ].map((activity, i) => (
                <tr key={i} className="hover:bg-gray-50">
                  <td className="px-6 py-4 text-sm text-gray-600">{activity.time}</td>
                  <td className="px-6 py-4 text-sm text-gray-900 font-medium">{activity.action}</td>
                  <td className="px-6 py-4 text-sm text-gray-900">{activity.amount}</td>
                  <td className="px-6 py-4">
                    <span className="px-2 py-1 bg-green-100 text-green-700 rounded text-xs font-medium">
                      Complete
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
