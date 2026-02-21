#!/bin/bash
# Certora Formal Verification Script
#
# Prerequisites:
#   1. Install Certora CLI: pip install certora-cli
#   2. Set CERTORAKEY environment variable with your API key
#
# Usage:
#   ./scripts/run-certora.sh [spec_name]
#
# Examples:
#   ./scripts/run-certora.sh                    # Run all specs
#   ./scripts/run-certora.sh PositionManager    # Run specific spec

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   IRS Protocol Formal Verification${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if Certora is installed
if ! command -v certoraRun &> /dev/null; then
    echo -e "${RED}Error: Certora CLI is not installed${NC}"
    echo "Install with: pip install certora-cli"
    exit 1
fi

# Check for API key
if [[ -z "${CERTORAKEY}" ]]; then
    echo -e "${YELLOW}Warning: CERTORAKEY not set${NC}"
    echo "Get your API key from: https://www.certora.com/"
    echo "Then: export CERTORAKEY=your_key"
    exit 1
fi

# Parse arguments
SPEC_FILTER="${1:-}"

# Define available specs
SPECS=(
    "PositionManager"
    # Add more specs as they're created
    # "MarginEngine"
    # "SettlementEngine"
)

# Run verification
for spec in "${SPECS[@]}"; do
    # Skip if filtering and doesn't match
    if [[ -n "$SPEC_FILTER" && "$spec" != "$SPEC_FILTER" ]]; then
        continue
    fi

    conf_file="certora/conf/${spec}.conf"

    if [[ ! -f "$conf_file" ]]; then
        echo -e "${YELLOW}Warning: $conf_file not found, skipping${NC}"
        continue
    fi

    echo -e "\n${BLUE}Verifying: $spec${NC}"
    echo -e "${BLUE}Config: $conf_file${NC}"

    # Run Certora
    certoraRun "$conf_file" || {
        echo -e "${RED}Verification failed for $spec${NC}"
        exit 1
    }

    echo -e "${GREEN}Verification completed for $spec${NC}"
done

echo -e "\n${GREEN}All verifications completed!${NC}"
echo -e "Check the Certora web interface for detailed results."
