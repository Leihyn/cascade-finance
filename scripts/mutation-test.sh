#!/bin/bash
# Mutation Testing Script using Gambit
#
# Prerequisites:
#   1. Install Gambit: pip install gambit-sol
#   2. Ensure forge is available in PATH
#
# Usage:
#   ./scripts/mutation-test.sh [contract_name] [num_mutants]
#
# Examples:
#   ./scripts/mutation-test.sh                    # Run all contracts
#   ./scripts/mutation-test.sh PositionManager    # Run specific contract
#   ./scripts/mutation-test.sh PositionManager 20 # Generate 20 mutants

set -e

# Configuration
GAMBIT_OUT="gambit_out"
CONTRACTS_DIR="src"
TEST_TIMEOUT=120
PARALLEL_JOBS=4

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
CONTRACT_FILTER="${1:-}"
NUM_MUTANTS="${2:-50}"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   IRS Protocol Mutation Testing${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if gambit is installed
if ! command -v gambit &> /dev/null; then
    echo -e "${RED}Error: Gambit is not installed${NC}"
    echo "Install with: pip install gambit-sol"
    exit 1
fi

# Clean previous output
rm -rf "$GAMBIT_OUT"
mkdir -p "$GAMBIT_OUT"

# Define contracts to test
declare -A CONTRACTS
CONTRACTS=(
    ["PositionManager"]="src/core/PositionManager.sol"
    ["SettlementEngine"]="src/core/SettlementEngine.sol"
    ["MarginEngine"]="src/risk/MarginEngine.sol"
    ["LiquidationEngine"]="src/risk/LiquidationEngine.sol"
    ["RateOracle"]="src/pricing/RateOracle.sol"
    ["FixedPointMath"]="src/libraries/FixedPointMath.sol"
)

# Statistics
TOTAL_MUTANTS=0
KILLED_MUTANTS=0
SURVIVED_MUTANTS=0
TIMEOUT_MUTANTS=0

# Function to test a single mutant
test_mutant() {
    local mutant_file=$1
    local original_file=$2
    local mutant_num=$3

    # Backup original
    cp "$original_file" "${original_file}.backup"

    # Apply mutant
    cp "$mutant_file" "$original_file"

    # Run tests with timeout
    if timeout $TEST_TIMEOUT forge test --no-match-path "test/fork/*" > /dev/null 2>&1; then
        echo -e "  ${YELLOW}SURVIVED${NC}: Mutant #$mutant_num"
        echo "$mutant_file" >> "$GAMBIT_OUT/survived.txt"
        ((SURVIVED_MUTANTS++)) || true
    else
        echo -e "  ${GREEN}KILLED${NC}: Mutant #$mutant_num"
        ((KILLED_MUTANTS++)) || true
    fi

    # Restore original
    mv "${original_file}.backup" "$original_file"
    ((TOTAL_MUTANTS++)) || true
}

# Process contracts
for contract in "${!CONTRACTS[@]}"; do
    # Skip if filtering and doesn't match
    if [[ -n "$CONTRACT_FILTER" && "$contract" != "$CONTRACT_FILTER" ]]; then
        continue
    fi

    contract_path="${CONTRACTS[$contract]}"

    if [[ ! -f "$contract_path" ]]; then
        echo -e "${YELLOW}Warning: $contract_path not found, skipping${NC}"
        continue
    fi

    echo -e "\n${BLUE}Processing: $contract${NC}"
    echo -e "${BLUE}Path: $contract_path${NC}"

    # Generate mutants
    echo "Generating $NUM_MUTANTS mutants..."
    gambit mutate "$contract_path" \
        --outdir "$GAMBIT_OUT/$contract" \
        --num-mutants "$NUM_MUTANTS" \
        --seed 42 2>/dev/null || {
        echo -e "${YELLOW}Warning: Could not generate mutants for $contract${NC}"
        continue
    }

    # Count mutants generated
    mutant_dir="$GAMBIT_OUT/$contract/mutants"
    if [[ -d "$mutant_dir" ]]; then
        mutant_count=$(find "$mutant_dir" -name "*.sol" | wc -l)
        echo "Generated $mutant_count mutants"

        # Test each mutant
        find "$mutant_dir" -name "*.sol" | while read -r mutant; do
            mutant_num=$(basename "$mutant" .sol | sed 's/.*_//')
            test_mutant "$mutant" "$contract_path" "$mutant_num"
        done
    else
        echo -e "${YELLOW}No mutants generated${NC}"
    fi
done

# Summary
echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}   Mutation Testing Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Total Mutants:    $TOTAL_MUTANTS"
echo -e "${GREEN}Killed:           $KILLED_MUTANTS${NC}"
echo -e "${YELLOW}Survived:         $SURVIVED_MUTANTS${NC}"

if [[ $TOTAL_MUTANTS -gt 0 ]]; then
    score=$((KILLED_MUTANTS * 100 / TOTAL_MUTANTS))
    echo -e "\n${BLUE}Mutation Score: ${score}%${NC}"

    if [[ $score -ge 80 ]]; then
        echo -e "${GREEN}Excellent! Test suite has good mutation coverage.${NC}"
    elif [[ $score -ge 60 ]]; then
        echo -e "${YELLOW}Good, but consider improving test coverage.${NC}"
    else
        echo -e "${RED}Warning: Low mutation score. Tests may be missing edge cases.${NC}"
    fi
fi

# Save surviving mutants for analysis
if [[ -f "$GAMBIT_OUT/survived.txt" ]]; then
    echo -e "\n${YELLOW}Surviving mutants saved to: $GAMBIT_OUT/survived.txt${NC}"
    echo "Review these to improve test coverage."
fi

echo -e "\n${BLUE}Mutation testing complete!${NC}"
