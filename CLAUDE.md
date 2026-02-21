# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cascade Finance: Full-stack DeFi ecosystem on Flow EVM with three integrated components:
- **Lending SDK** (Compound V3-style): Single-pool lending with jump rate model
- **DEX SDK** (Uniswap V2-style): Constant product AMM with LP tokens
- **Cascade IRS** (Core product): Interest rate swaps with ERC721 positions

Cascade IRS uses real interest rates from the Lending SDK via CometRateAdapter for interest rate speculation.

## Build Commands

```bash
forge install    # Install dependencies
forge build      # Build contracts
forge fmt        # Format code
```

## Testing Commands

```bash
# Run all tests (328+ tests)
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path "test/unit/PositionManager.t.sol" -vvv

# Run tests by module
forge test --match-path "test/lending/*" -vvv
forge test --match-path "test/dex/*" -vvv
forge test --match-path "test/invariant/*" -vvv

# Gas benchmarks
forge test --match-path "test/gas/*" --gas-report
```

## Deployment

```bash
# Deploy full stack to Flow EVM Testnet
forge script script/DeployFull.s.sol:DeployFull \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  --broadcast \
  --private-key $PRIVATE_KEY

# Verify contracts on FlowScan
forge verify-contract <ADDRESS> <CONTRACT_PATH> \
  --verifier blockscout \
  --verifier-url https://evm-testnet.flowscan.io/api
```

## Frontend

```bash
cd frontend
npm install
npm run dev    # Starts on http://localhost:3000
npm run build  # Production build
```

## Architecture

```
src/
+-- core/                    # Cascade IRS core
|   +-- PositionManager.sol  # ERC721 position NFTs (main entry point)
|   +-- SettlementEngine.sol # Hourly PnL settlements
|   +-- OrderBook.sol        # Peer-to-peer order matching
|   +-- Automation.sol       # Keeper automation
+-- lending/                 # Lending SDK
|   +-- Comet.sol           # Main lending pool
|   +-- CometFactory.sol    # Market deployment factory
|   +-- models/JumpRateModel.sol
+-- dex/                     # DEX SDK
|   +-- core/SwapPair.sol   # AMM pool with LP tokens
|   +-- core/SwapFactory.sol
|   +-- periphery/SwapRouter.sol
+-- risk/                    # Risk management
|   +-- MarginEngine.sol    # Health factor & margin calculations
|   +-- LiquidationEngine.sol
+-- pricing/                 # Oracles
|   +-- RateOracle.sol      # Aggregated rate oracle (median)
+-- adapters/                # Rate bridges
|   +-- CometRateAdapter.sol # Comet -> RateOracle bridge
+-- libraries/
    +-- FixedPointMath.sol  # WAD (1e18) / RAY (1e27) precision
```

## Configuration

- **Solidity**: 0.8.24 with `via_ir = true` optimization
- **Optimizer**: 200 runs
- **Fuzz runs**: 10,000
- **Invariant runs**: 1,000 (depth 50)

## Environment Variables

Copy `.env.example` to `.env`:
- `FLOW_TESTNET_RPC_URL` - Flow EVM Testnet (https://testnet.evm.nodes.onflow.org)
- `FLOW_MAINNET_RPC_URL` - Flow EVM Mainnet (https://mainnet.evm.nodes.onflow.org)
- `PRIVATE_KEY` - Deployer private key

## Network Details

- **Flow EVM Testnet**: Chain ID 545, Explorer: https://evm-testnet.flowscan.io
- **Flow EVM Mainnet**: Chain ID 747, Explorer: https://evm.flowscan.io
- **Faucet**: https://faucet.flow.com/fund-account
