"use client";

import { useState, useCallback } from "react";

export interface WizardState {
  step: number;
  isPayingFixed: boolean;
  notional: string;
  fixedRate: string;
  maturityDays: string;
  margin: string;
}

export interface UsePositionWizardReturn {
  state: WizardState;
  step: number;
  totalSteps: number;
  isFirstStep: boolean;
  isLastStep: boolean;
  setStep: (step: number) => void;
  nextStep: () => void;
  prevStep: () => void;
  updateField: <K extends keyof WizardState>(field: K, value: WizardState[K]) => void;
  reset: () => void;
  canProceed: boolean;
  getStepValidation: (step: number) => { isValid: boolean; errors: string[] };
}

const TOTAL_STEPS = 4;

const initialState: WizardState = {
  step: 1,
  isPayingFixed: true,
  notional: "10000",
  fixedRate: "5",
  maturityDays: "90",
  margin: "1000",
};

export function usePositionWizard(): UsePositionWizardReturn {
  const [state, setState] = useState<WizardState>(initialState);

  const setStep = useCallback((step: number) => {
    if (step >= 1 && step <= TOTAL_STEPS) {
      setState((prev) => ({ ...prev, step }));
    }
  }, []);

  const nextStep = useCallback(() => {
    setState((prev) => ({
      ...prev,
      step: Math.min(prev.step + 1, TOTAL_STEPS),
    }));
  }, []);

  const prevStep = useCallback(() => {
    setState((prev) => ({
      ...prev,
      step: Math.max(prev.step - 1, 1),
    }));
  }, []);

  const updateField = useCallback(
    <K extends keyof WizardState>(field: K, value: WizardState[K]) => {
      setState((prev) => ({ ...prev, [field]: value }));
    },
    []
  );

  const reset = useCallback(() => {
    setState(initialState);
  }, []);

  const getStepValidation = useCallback(
    (step: number): { isValid: boolean; errors: string[] } => {
      const errors: string[] = [];

      switch (step) {
        case 1:
          // Position type is always valid (just a selection)
          return { isValid: true, errors: [] };

        case 2:
          // Validate rate and maturity
          const rate = parseFloat(state.fixedRate);
          if (isNaN(rate) || rate <= 0 || rate > 100) {
            errors.push("Fixed rate must be between 0 and 100%");
          }
          const maturity = parseInt(state.maturityDays);
          if (isNaN(maturity) || maturity < 1) {
            errors.push("Maturity must be at least 1 day");
          }
          return { isValid: errors.length === 0, errors };

        case 3:
          // Validate notional and margin
          const notional = parseFloat(state.notional);
          if (isNaN(notional) || notional < 100) {
            errors.push("Notional must be at least $100");
          }
          const margin = parseFloat(state.margin);
          if (isNaN(margin) || margin < 1) {
            errors.push("Margin must be at least $1");
          }
          const minMargin = notional * 0.1;
          if (margin < minMargin) {
            errors.push(`Margin must be at least ${minMargin.toFixed(0)} (10% of notional)`);
          }
          return { isValid: errors.length === 0, errors };

        case 4:
          // Review step - validate everything
          const allValidation = [
            getStepValidation(1),
            getStepValidation(2),
            getStepValidation(3),
          ];
          const allErrors = allValidation.flatMap((v) => v.errors);
          return { isValid: allErrors.length === 0, errors: allErrors };

        default:
          return { isValid: true, errors: [] };
      }
    },
    [state]
  );

  const canProceed = getStepValidation(state.step).isValid;

  return {
    state,
    step: state.step,
    totalSteps: TOTAL_STEPS,
    isFirstStep: state.step === 1,
    isLastStep: state.step === TOTAL_STEPS,
    setStep,
    nextStep,
    prevStep,
    updateField,
    reset,
    canProceed,
    getStepValidation,
  };
}
