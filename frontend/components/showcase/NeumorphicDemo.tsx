export function NeumorphicDemo() {
  return (
    <div className="min-h-screen bg-[#1e1e2e] p-8">
      <div className="max-w-6xl mx-auto">
        {/* Soft Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-4 mb-4">
            <div
              className="w-16 h-16 rounded-2xl bg-[#1e1e2e] flex items-center justify-center"
              style={{
                boxShadow: "8px 8px 16px #16161f, -8px -8px 16px #2d2d44",
              }}
            >
              <span className="text-3xl">🎨</span>
            </div>
            <h1 className="text-5xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[#B4BEFE] to-[#F5C2E7]">
              Cascade Finance
            </h1>
          </div>
          <p className="text-[#A6ADC8] text-lg">Premium Financial Services</p>
        </div>

        {/* Neumorphic Cards */}
        <div className="grid md:grid-cols-3 gap-8 mb-8">
          {/* Position Card - Extruded */}
          <div
            className="bg-[#1e1e2e] rounded-3xl p-8"
            style={{
              boxShadow: "10px 10px 20px #16161f, -10px -10px 20px #2d2d44",
            }}
          >
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold text-[#CDD6F4]">Position #1234</h3>
              <div
                className="px-4 py-2 rounded-2xl text-[#A6E3A1] font-semibold text-sm bg-[#1e1e2e]"
                style={{
                  boxShadow: "inset 3px 3px 6px #16161f, inset -3px -3px 6px #2d2d44",
                }}
              >
                Active
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex justify-between">
                <span className="text-[#7F849C]">Type</span>
                <span className="text-[#B4BEFE] font-semibold">Pay Fixed</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[#7F849C]">Notional</span>
                <span className="text-[#CDD6F4] font-semibold">10,000 USDC</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[#7F849C]">Fixed Rate</span>
                <span className="text-[#F9E2AF] font-bold">6.50%</span>
              </div>
              <div className="pt-4 border-t border-[#2d2d44] flex justify-between">
                <span className="text-[#7F849C]">PnL</span>
                <div>
                  <div className="text-2xl font-bold text-[#A6E3A1]">+$523.42</div>
                  <div className="text-sm text-[#A6E3A1]">+5.23%</div>
                </div>
              </div>
            </div>

            <button
              className="w-full mt-6 py-4 bg-[#1e1e2e] rounded-2xl font-bold text-[#B4BEFE] transition-all hover:text-[#F5C2E7]"
              style={{
                boxShadow: "5px 5px 10px #16161f, -5px -5px 10px #2d2d44",
              }}
              onMouseDown={(e) => {
                e.currentTarget.style.boxShadow = "inset 3px 3px 6px #16161f, inset -3px -3px 6px #2d2d44";
              }}
              onMouseUp={(e) => {
                e.currentTarget.style.boxShadow = "5px 5px 10px #16161f, -5px -5px 10px #2d2d44";
              }}
            >
              Manage Position
            </button>
          </div>

          {/* Stats Card - Soft Pressed */}
          <div
            className="bg-[#1e1e2e] rounded-3xl p-8"
            style={{
              boxShadow: "inset 8px 8px 16px #16161f, inset -8px -8px 16px #2d2d44",
            }}
          >
            <h3 className="text-lg font-bold text-[#CDD6F4] mb-6">Portfolio Stats</h3>

            <div className="space-y-6">
              <div>
                <div className="text-sm text-[#7F849C] mb-2">Total Value Locked</div>
                <div className="text-3xl font-bold text-[#CDD6F4]">$1,234,567</div>
                <div
                  className="h-3 bg-[#1e1e2e] rounded-full mt-3 overflow-hidden"
                  style={{
                    boxShadow: "inset 3px 3px 6px #16161f, inset -3px -3px 6px #2d2d44",
                  }}
                >
                  <div
                    className="h-full bg-gradient-to-r from-[#B4BEFE] to-[#F5C2E7] rounded-full"
                    style={{ width: "75%", boxShadow: "0 0 10px rgba(180, 190, 254, 0.5)" }}
                  />
                </div>
              </div>

              <div>
                <div className="text-sm text-[#7F849C] mb-2">Total PnL</div>
                <div className="text-3xl font-bold text-[#A6E3A1]">+$12,345</div>
              </div>

              <div>
                <div className="text-sm text-[#7F849C] mb-2">Active Positions</div>
                <div className="text-3xl font-bold text-[#89B4FA]">8</div>
              </div>
            </div>
          </div>

          {/* Actions Card */}
          <div
            className="bg-[#1e1e2e] rounded-3xl p-8"
            style={{
              boxShadow: "10px 10px 20px #16161f, -10px -10px 20px #2d2d44",
            }}
          >
            <h3 className="text-lg font-bold text-[#CDD6F4] mb-6">Quick Actions</h3>

            <div className="space-y-4">
              {["Open Position", "View All", "Analytics"].map((action, i) => (
                <button
                  key={action}
                  className="w-full py-4 bg-[#1e1e2e] rounded-2xl font-semibold text-[#B4BEFE] transition-all hover:text-[#F5C2E7]"
                  style={{
                    boxShadow: "5px 5px 10px #16161f, -5px -5px 10px #2d2d44",
                  }}
                  onMouseDown={(e) => {
                    e.currentTarget.style.boxShadow = "inset 3px 3px 6px #16161f, inset -3px -3px 6px #2d2d44";
                  }}
                  onMouseUp={(e) => {
                    e.currentTarget.style.boxShadow = "5px 5px 10px #16161f, -5px -5px 10px #2d2d44";
                  }}
                >
                  {action}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Feature Icons */}
        <div className="grid grid-cols-4 gap-6">
          {[
            { icon: "🛡️", label: "Secure", color: "#B4BEFE" },
            { icon: "⚡", label: "Fast", color: "#F9E2AF" },
            { icon: "💎", label: "Premium", color: "#F5C2E7" },
            { icon: "🌙", label: "Smooth", color: "#89B4FA" },
          ].map((feature) => (
            <div
              key={feature.label}
              className="bg-[#1e1e2e] rounded-2xl p-6 text-center transition-all hover:scale-105"
              style={{
                boxShadow: "8px 8px 16px #16161f, -8px -8px 16px #2d2d44",
              }}
            >
              <div className="text-4xl mb-3">{feature.icon}</div>
              <div className="font-semibold" style={{ color: feature.color }}>
                {feature.label}
              </div>
            </div>
          ))}
        </div>

        {/* Soft Toggle Example */}
        <div className="mt-8 flex justify-center">
          <div
            className="inline-flex bg-[#1e1e2e] p-2 rounded-2xl gap-2"
            style={{
              boxShadow: "inset 5px 5px 10px #16161f, inset -5px -5px 10px #2d2d44",
            }}
          >
            {["Overview", "Positions", "Analytics"].map((tab) => (
              <button
                key={tab}
                className="px-6 py-3 bg-[#1e1e2e] rounded-xl font-medium text-[#A6ADC8] transition-all hover:text-[#B4BEFE]"
                style={{
                  boxShadow: "4px 4px 8px #16161f, -4px -4px 8px #2d2d44",
                }}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
