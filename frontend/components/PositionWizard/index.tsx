"use client";

import { useEffect } from "react";
import { useWriteContract, useReadContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { POSITION_MANAGER_ABI, ERC20_ABI, RATE_ORACLE_ABI } from "@/lib/abis";
import { useToast, parseError } from "../ui/Toast";
import { usePositionWizard } from "@/hooks/usePositionWizard";
import { StepIndicator } from "./StepIndicator";
import { Step1PositionType } from "./Step1PositionType";
import { Step2Parameters } from "./Step2Parameters";
import { Step3Margin } from "./Step3Margin";
import { Step4Review } from "./Step4Review";

interface Props {
  contracts: {
    positionManager: `0x${string}`;
    rateOracle: `0x${string}`;
    usdc: `0x${string}`;
  };
  onSwitchToAdvanced?: () => void;
}

export function PositionWizard({ contracts, onSwitchToAdvanced }: Props) {
  const { address } = useAccount();
  const { addToast } = useToast();
  const wizard = usePositionWizard();

  const { writeContract, isPending, data: hash, error, reset } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  // Get current floating rate
  const { data: currentRate } = useReadContract({
    address: contracts.rateOracle,
    abi: RATE_ORACLE_ABI,
    functionName: "getCurrentRate",
  });

  // Get USDC allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: contracts.usdc,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address!, contracts.positionManager],
  });

  // Handle transaction completion
  useEffect(() => {
    if (isConfirmed) {
      addToast({ type: "success", title: "Success", message: "Position opened successfully!" });
      refetchAllowance();
      reset();
      wizard.reset();
    } else if (error) {
      addToast({ type: "error", title: "Error", message: parseError(error) });
      reset();
    }
  }, [isConfirmed, error, refetchAllowance, reset, addToast, wizard]);

  const handleApprove = () => {
    writeContract({
      address: contracts.usdc,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [contracts.positionManager, parseUnits("1000000", 6)],
    });
  };

  const handleOpenPosition = () => {
    writeContract({
      address: contracts.positionManager,
      abi: POSITION_MANAGER_ABI,
      functionName: "openPosition",
      args: [
        wizard.state.isPayingFixed,
        parseUnits(wizard.state.notional, 6),
        parseUnits(wizard.state.fixedRate, 16),
        BigInt(wizard.state.maturityDays),
        parseUnits(wizard.state.margin, 6),
      ],
    });
  };

  const needsApproval = !allowance || allowance < parseUnits(wizard.state.margin, 6);
  const isWorking = isPending || isConfirming;

  const currentFloatingRate = currentRate
    ? Number(formatUnits(currentRate, 18)) * 100
    : 5.5;

  const floatingRateDisplay = currentFloatingRate.toFixed(2);

  const validation = wizard.getStepValidation(wizard.step);

  return (
    <div className="terminal-window">
      {/* Terminal Header */}
      <div className="terminal-header">
        POSITION_WIZARD.sh
        {onSwitchToAdvanced && (
          <button
            type="button"
            onClick={onSwitchToAdvanced}
            className="ml-auto text-xs bg-transparent border-0 text-black hover:opacity-70 uppercase font-bold"
            style={{ all: 'unset', marginLeft: 'auto', cursor: 'pointer', fontSize: '11px', fontWeight: 700 }}
          >
            [ADV]
          </button>
        )}
      </div>

      <div className="p-4 sm:p-6">{/* Content wrapper */}

      {/* Step Indicator */}
      <StepIndicator currentStep={wizard.step} totalSteps={wizard.totalSteps} />

      {/* Step Content */}
      <div className="min-h-[400px]">
        {wizard.step === 1 && (
          <Step1PositionType
            isPayingFixed={wizard.state.isPayingFixed}
            onSelect={(isPayingFixed) => wizard.updateField("isPayingFixed", isPayingFixed)}
            currentFloatingRate={floatingRateDisplay}
          />
        )}

        {wizard.step === 2 && (
          <Step2Parameters
            isPayingFixed={wizard.state.isPayingFixed}
            fixedRate={wizard.state.fixedRate}
            maturityDays={wizard.state.maturityDays}
            currentFloatingRate={currentFloatingRate}
            onFixedRateChange={(value) => wizard.updateField("fixedRate", value)}
            onMaturityChange={(value) => wizard.updateField("maturityDays", value)}
            notional={wizard.state.notional}
          />
        )}

        {wizard.step === 3 && (
          <Step3Margin
            notional={wizard.state.notional}
            margin={wizard.state.margin}
            onNotionalChange={(value) => wizard.updateField("notional", value)}
            onMarginChange={(value) => wizard.updateField("margin", value)}
          />
        )}

        {wizard.step === 4 && (
          <Step4Review
            isPayingFixed={wizard.state.isPayingFixed}
            notional={wizard.state.notional}
            fixedRate={wizard.state.fixedRate}
            maturityDays={wizard.state.maturityDays}
            margin={wizard.state.margin}
            currentFloatingRate={currentFloatingRate}
            errors={validation.errors}
          />
        )}
      </div>

      {/* Transaction Status */}
      {(isPending || isConfirming) && (
        <div className="mt-4 p-3 border border-[--terminal-blue] bg-black text-[--terminal-blue] text-center font-mono text-sm">
          <div className="status-info inline-block">
            {isPending ? "Awaiting wallet signature..." : "Broadcasting transaction..."}
          </div>
        </div>
      )}

      {/* Navigation Buttons */}
      <div className="mt-6 flex gap-3">
        {/* Back Button */}
        {!wizard.isFirstStep && (
          <button
            type="button"
            onClick={wizard.prevStep}
            disabled={isWorking}
            className="flex-1 py-3 min-h-[48px] neon-button disabled:opacity-50"
          >
            Back
          </button>
        )}

        {/* Next/Submit Button */}
        {wizard.isLastStep ? (
          needsApproval ? (
            <button
              type="button"
              onClick={handleApprove}
              disabled={isWorking || !validation.isValid}
              className="flex-1 py-3 min-h-[48px] neon-button warning disabled:opacity-50"
            >
              {isWorking ? (isConfirming ? "Confirming..." : "Approving...") : "Approve USDC"}
            </button>
          ) : (
            <button
              type="button"
              onClick={handleOpenPosition}
              disabled={isWorking || !validation.isValid}
              className="flex-1 py-3 min-h-[48px] neon-button primary disabled:opacity-50"
            >
              {isWorking ? (isConfirming ? "Confirming..." : "Opening...") : "Open Position"}
            </button>
          )
        ) : (
          <button
            type="button"
            onClick={wizard.nextStep}
            disabled={!wizard.canProceed}
            className="flex-1 py-3 min-h-[48px] neon-button primary disabled:opacity-50"
          >
            Continue
          </button>
        )}
      </div>
      </div>{/* Close content wrapper */}
    </div>
  );
}
