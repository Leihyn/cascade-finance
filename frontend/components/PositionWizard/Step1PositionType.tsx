"use client";

interface Props {
  isPayingFixed: boolean;
  onSelect: (isPayingFixed: boolean) => void;
  currentFloatingRate: string;
}

export function Step1PositionType({
  isPayingFixed,
  onSelect,
  currentFloatingRate,
}: Props) {
  const strategies = [
    {
      id: "pay-fixed",
      title: "Pay Fixed Rate",
      subtitle: "Receive Floating Rate",
      description:
        "You lock in a fixed rate payment and receive the variable floating rate. Profit when floating rates rise above your fixed rate.",
      icon: (
        <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
        </svg>
      ),
      when: "When you expect rates to rise",
      isSelected: isPayingFixed,
      color: "indigo",
    },
    {
      id: "pay-floating",
      title: "Pay Floating Rate",
      subtitle: "Receive Fixed Rate",
      description:
        "You pay the variable floating rate and receive a fixed rate. Profit when floating rates fall below your fixed rate.",
      icon: (
        <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 17h8m0 0v-8m0 8l-8-8-4 4-6-6" />
        </svg>
      ),
      when: "When you expect rates to fall",
      isSelected: !isPayingFixed,
      color: "purple",
    },
  ];

  return (
    <div className="space-y-6">
      <div className="mb-6 font-mono">
        <div className="text-center border border-[--terminal-green-dark] p-4 bg-[--bg-secondary]">
          <div className="text-sm text-[--text-comment] mb-2">$ cat STRATEGY.txt</div>
          <h3 className="text-lg font-bold text-[--terminal-green] mb-2 uppercase tracking-wider">
            Choose Your Strategy
          </h3>
          <div className="text-sm text-[--text-secondary]">
            <span className="text-[--text-comment]">floating_rate:</span> {currentFloatingRate}%
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {strategies.map((strategy) => (
          <button
            key={strategy.id}
            type="button"
            onClick={() => onSelect(strategy.id === "pay-fixed")}
            className={`relative p-5 border-2 text-left transition-all font-mono ${
              strategy.isSelected
                ? "border-[--terminal-green] bg-[--bg-secondary] shadow-[0_0_15px_rgba(0,255,65,0.3)]"
                : "border-[--terminal-green-dark] bg-black hover:border-[--terminal-green-dim]"
            }`}
          >
            {/* Selected indicator */}
            {strategy.isSelected && (
              <div className="absolute top-3 right-3 text-[--terminal-green] font-bold text-sm">
                [✓]
              </div>
            )}

            {/* ASCII Icon */}
            <div
              className={`mb-4 text-2xl ${
                strategy.isSelected
                  ? "text-[--terminal-green]"
                  : "text-[--text-comment]"
              }`}
            >
              {strategy.id === "pay-fixed" ? "▲" : "▼"}
            </div>

            {/* Title */}
            <h4 className={`font-bold mb-1 uppercase text-sm ${
              strategy.isSelected
                ? "text-[--terminal-green]"
                : "text-[--text-secondary]"
            }`}>
              {strategy.title}
            </h4>
            <p className={`text-xs mb-3 ${
                strategy.isSelected
                  ? "text-[--text-secondary]"
                  : "text-[--text-comment]"
              }`}
            >
              └─ {strategy.subtitle}
            </p>

            {/* Description */}
            <p className="text-xs text-[--text-comment] mb-3 leading-relaxed">
              {strategy.description}
            </p>

            {/* Best when badge */}
            <div className={`inline-flex items-center text-xs px-2 py-1 border ${
                strategy.isSelected
                  ? "border-[--terminal-green] text-[--terminal-green]"
                  : "border-[--terminal-green-dark] text-[--text-comment]"
              }`}
            >
              {strategy.when}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
