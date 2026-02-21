"use client";

interface Props {
  currentStep: number;
  totalSteps: number;
  stepLabels?: string[];
}

const DEFAULT_LABELS = ["Type", "Rate", "Size", "Review"];

export function StepIndicator({
  currentStep,
  totalSteps,
  stepLabels = DEFAULT_LABELS,
}: Props) {
  return (
    <div className="mb-6 sm:mb-8">
      {/* Terminal Progress */}
      <div className="font-mono text-sm">
        {/* ASCII Progress Bar */}
        <div className="flex items-center gap-2 mb-4 text-[--terminal-green]">
          <span className="text-[--text-comment]">$</span>
          <span className="text-[--text-comment]">progress:</span>
          <div className="flex-1 border border-[--terminal-green-dark] bg-black px-2 py-1">
            {Array.from({ length: totalSteps }, (_, i) => i + 1).map((step) => {
              const isCompleted = step < currentStep;
              const isCurrent = step === currentStep;

              return (
                <span key={step}>
                  {isCompleted ? '█' : isCurrent ? '▓' : '░'}
                </span>
              );
            })}
            <span className="ml-2 text-[--text-secondary]">
              [{currentStep}/{totalSteps}]
            </span>
          </div>
        </div>

        {/* Step indicators */}
        <div className="relative flex justify-between">
          {Array.from({ length: totalSteps }, (_, i) => i + 1).map((step) => {
            const isCompleted = step < currentStep;
            const isCurrent = step === currentStep;
            const isPending = step > currentStep;

            return (
              <div key={step} className="flex flex-col items-center">
                {/* Terminal Box */}
                <div
                  className={`w-10 h-10 border flex items-center justify-center text-sm font-bold transition-all duration-300 font-mono ${
                    isCompleted
                      ? "border-[--terminal-green] bg-[--terminal-green] text-black"
                      : isCurrent
                      ? "border-[--terminal-green] bg-black text-[--terminal-green] shadow-[0_0_10px_var(--terminal-green)]"
                      : "border-[--terminal-green-dark] bg-black text-[--text-comment]"
                  }`}
                >
                  {isCompleted ? '[✓]' : step}
                </div>

                {/* Label */}
                <span
                  className={`mt-2 text-xs sm:text-sm transition-colors uppercase tracking-wider ${
                    isCurrent
                      ? "text-[--terminal-green] font-bold"
                      : isCompleted
                      ? "text-[--text-secondary]"
                      : "text-[--text-comment]"
                  }`}
                >
                  {stepLabels[step - 1] || `Step ${step}`}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
