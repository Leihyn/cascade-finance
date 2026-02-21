# Cascade Finance - Composable Interest Rate Derivatives on Flow

<div align="center">

[![Flow Network](https://img.shields.io/badge/Flow-EVM-00EF8B?style=for-the-badge&logo=flow&logoColor=white)](https://flow.com)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?style=for-the-badge&logo=solidity&logoColor=white)](https://soliditylang.org)
[![License](https://img.shields.io/badge/License-MIT-00EF8B?style=for-the-badge)](LICENSE)

**Track**: DeFi | [Live on Flow EVM Testnet](https://evm-testnet.flowscan.io)

</div>

---

## The Problem

Interest rate swaps are a **$500+ trillion market** in traditional finance. In DeFi, this market barely exists.

A yield farmer deposits $50,000 into a lending pool expecting 5% APY. Two weeks later, rates crash to 1.2%. Months of expected yield gone, with no warning and no way to hedge.

Meanwhile, traders who see rate increases coming have no instrument to profit from that view. The entire DeFi interest rate market is a one-way street: you accept whatever the pool gives you.

## The Solution

**Cascade Finance** brings institutional-grade interest rate derivatives to Flow EVM. Three composable protocols working together:

- **Lending SDK** -- Supply and borrow with dynamic rates (Compound V3 architecture)
- **DEX SDK** -- Constant product AMM for token swaps (Uniswap V2 architecture)
- **Cascade IRS** -- Trade fixed vs floating interest rates as ERC721 position NFTs

The lending pool generates real rates. The IRS protocol lets you trade views on where those rates are headed. Every position is an NFT you can transfer, sell, or use as collateral elsewhere.

## Why Flow?

Flow's architecture makes this protocol viable where other chains can't:

| Feature | Impact on Cascade |
|---------|-------------------|
| **Sub-cent gas fees** | Hourly automated settlements cost < $0.01 each |
| **~1s perceived finality** | Position opens and confirms in seconds |
| **No MEV** | Proposer-builder separation protects rate traders from sandwich attacks |
| **Native VRF** | On-chain randomness via Cadence Arch (no external oracle needed) |
| **EVM equivalent** | Full Solidity compatibility, standard tooling |

A $10,000 interest rate swap position on Ethereum L1 costs ~$50 to open and ~$30 per hourly settlement. On Flow, the same operations cost fractions of a cent. This makes the product accessible to retail users, not just institutions.

## Architecture

```
+-------------------------------------------------------------+
|                   CASCADE IRS (Core Protocol)                |
|  +---------------+  +--------------+  +-------------------+ |
|  | PositionMgr   |  | Settlement   |  | MarginEngine      | |
|  |   (ERC721)    |  |   Engine     |  | LiquidationEngine | |
|  +-------+-------+  +------+-------+  +---------+---------+ |
+-----------+----------------+--------------------+------------+
            |                |                    |
            v                v                    v
+-----------------+  +--------------+  +---------------------+
|  LENDING SDK    |  | RATE ORACLE  |  |      DEX SDK        |
|  +-----------+  |  |   (Bridge)   |  |  +---------------+  |
|  |   Comet   |  |  +------+------+  |  |    Factory     |  |
|  |  (Pool)   +--+----------+        |  |    Router      |  |
|  +-----------+  |                    |  |    Pairs       |  |
|  Interest Rates |                    |  +---------------+  |
+-----------------+                    +---------------------+
```

## How It Works

### 1. Lending Pool Generates Real Rates
Users supply USDC to earn interest. The pool tracks supply rate, borrow rate, and utilization. Interest rates follow a jump rate model: gradual increase up to 80% utilization, then a sharp jump.

### 2. Rate Oracle Bridges to IRS
The `CometRateAdapter` reads real-time rates from the lending pool and feeds them into the IRS `RateOracle`. The oracle aggregates multiple sources, filters outliers via median calculation, and includes a circuit breaker for manipulation resistance.

### 3. Trade Interest Rate Views

**Pay Fixed, Receive Floating** -- Bet rates will rise
- You lock in a fixed rate (e.g., 5%)
- You receive whatever the market rate is
- Profit when floating > fixed

**Pay Floating, Receive Fixed** -- Bet rates will fall
- You pay the current market rate
- You receive a locked rate
- Profit when fixed > floating

**Settlement Example**:
A $10,000 position, fixed at 5%, current floating at 6%.
Hourly PnL (pay-fixed): +$10,000 x (6% - 5%) / 8760 = +$1.14

### 4. Risk Management
- **Margin Engine**: 10% initial margin, 5% maintenance, max 20x leverage
- **Liquidation Engine**: 5% bonus to liquidators, partial liquidation support
- **Circuit Breaker**: Rate oracle trips on >5x rate changes

## Quick Start

### Prerequisites
- [Foundry](https://getfoundry.sh) (forge, cast, anvil)
- Node.js 18+

### Smart Contracts

```bash
git clone https://github.com/YOUR_USERNAME/cascade-finance.git
cd cascade-finance

# Install dependencies
forge install

# Run all tests (328 tests)
forge test

# Run with gas reporting
forge test --gas-report

# Deploy to Flow EVM Testnet
forge script script/DeployFull.s.sol:DeployFull \
  --rpc-url https://testnet.evm.nodes.onflow.org \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Get testnet FLOW**: https://faucet.flow.com/fund-account

### Frontend

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:3000

## Deployed Contracts (Flow EVM Testnet)

**Network**: Flow EVM Testnet (Chain ID: 545)
**Explorer**: https://evm-testnet.flowscan.io

### Tokens
| Contract | Address |
|----------|---------|
| USDC | [`0x2C5Bedd15f3d40Da729A68D852E4f436dA14ef79`](https://evm-testnet.flowscan.io/address/0x2C5Bedd15f3d40Da729A68D852E4f436dA14ef79) |
| WFLOW | [`0x83388045cab4caDc82ACfa99a63b17E6d4E5Cc87`](https://evm-testnet.flowscan.io/address/0x83388045cab4caDc82ACfa99a63b17E6d4E5Cc87) |

### Lending SDK
| Contract | Address |
|----------|---------|
| Comet | [`0x15880a9E1719AAd5a37C99203c51C2E445651c94`](https://evm-testnet.flowscan.io/address/0x15880a9E1719AAd5a37C99203c51C2E445651c94) |
| CometFactory | [`0xb4A47F5D656C177be6cF4839551217f44cbb2Cb5`](https://evm-testnet.flowscan.io/address/0xb4A47F5D656C177be6cF4839551217f44cbb2Cb5) |
| JumpRateModel | [`0xcC86944f5E7385cA6Df8EEC5d40957840cfdfbb2`](https://evm-testnet.flowscan.io/address/0xcC86944f5E7385cA6Df8EEC5d40957840cfdfbb2) |

### DEX SDK
| Contract | Address |
|----------|---------|
| SwapFactory | [`0x2716c3E427B33c78d01e06a5Ba19A673EB5d898b`](https://evm-testnet.flowscan.io/address/0x2716c3E427B33c78d01e06a5Ba19A673EB5d898b) |
| SwapRouter | [`0x824d335886E8c516a121E2df59104F04cABAe30b`](https://evm-testnet.flowscan.io/address/0x824d335886E8c516a121E2df59104F04cABAe30b) |

### Cascade IRS Protocol
| Contract | Address |
|----------|---------|
| PositionManager | [`0x4A8705C1a7949F51DB589fA616f6f5c7ECf986e6`](https://evm-testnet.flowscan.io/address/0x4A8705C1a7949F51DB589fA616f6f5c7ECf986e6) |
| SettlementEngine | [`0x29Be033fC3bDa9cbfc623848AEf7d38Cd6113d84`](https://evm-testnet.flowscan.io/address/0x29Be033fC3bDa9cbfc623848AEf7d38Cd6113d84) |
| MarginEngine | [`0x8061CCD94E4E233BDc602A46aB43681c6026Fee0`](https://evm-testnet.flowscan.io/address/0x8061CCD94E4E233BDc602A46aB43681c6026Fee0) |
| LiquidationEngine | [`0x39618E21B20c18B54d9656d90Db7C4835Eb38b68`](https://evm-testnet.flowscan.io/address/0x39618E21B20c18B54d9656d90Db7C4835Eb38b68) |
| RateOracle | [`0x914664B39D8DF72601086ebf903b741907d9cCD0`](https://evm-testnet.flowscan.io/address/0x914664B39D8DF72601086ebf903b741907d9cCD0) |
| CometRateAdapter | [`0xff0D1Ef082Aabe9bb00DC3e599bcc7d885C683fe`](https://evm-testnet.flowscan.io/address/0xff0D1Ef082Aabe9bb00DC3e599bcc7d885C683fe) |
| PriceOracle | [`0x55Bd48C34441FEdA5c0D45a2400976fB933Abb7e`](https://evm-testnet.flowscan.io/address/0x55Bd48C34441FEdA5c0D45a2400976fB933Abb7e) |

## Project Structure

```
cascade-finance/
+-- src/
|   +-- core/               # Cascade IRS Protocol
|   |   +-- PositionManager.sol
|   |   +-- SettlementEngine.sol
|   +-- lending/             # Lending SDK
|   |   +-- Comet.sol
|   |   +-- CometFactory.sol
|   |   +-- models/JumpRateModel.sol
|   +-- dex/                 # DEX SDK
|   |   +-- core/SwapFactory.sol, SwapPair.sol
|   |   +-- periphery/SwapRouter.sol
|   +-- risk/                # Risk Management
|   |   +-- MarginEngine.sol
|   |   +-- LiquidationEngine.sol
|   +-- pricing/             # Oracle Infrastructure
|   |   +-- RateOracle.sol
|   +-- adapters/            # Rate Source Bridges
|   +-- libraries/           # Fixed-point math
+-- test/                    # 328 tests (unit, integration, invariant, gas)
+-- script/                  # Foundry deployment scripts
+-- frontend/                # Next.js 14 + wagmi v2 + RainbowKit
```

## Testing

```bash
# Full suite
forge test

# By module
forge test --match-path "test/unit/*" -vvv
forge test --match-path "test/integration/*" -vvv
forge test --match-path "test/invariant/*" -vvv
forge test --match-path "test/lending/*" -vvv
forge test --match-path "test/dex/*" -vvv

# Gas benchmarks
forge test --match-path "test/gas/*" --gas-report
```

328 tests passing across unit, integration, invariant/fuzz, and gas benchmark suites.

## Security

- Comprehensive test suite with invariant and fuzz testing (10,000 runs)
- Halmos symbolic execution for formal verification
- All critical/high findings from internal audit addressed
- ReentrancyGuard on all state-changing external functions
- Circuit breaker on rate oracle for manipulation resistance
- Margin system with health factor monitoring and automated liquidations

## Tech Stack

- **Smart Contracts**: Solidity 0.8.24, Foundry, OpenZeppelin
- **Frontend**: Next.js 14, wagmi v2, RainbowKit, viem
- **Testing**: Foundry (unit, fuzz, invariant, symbolic)
- **Network**: Flow EVM (Testnet: chain 545, Mainnet: chain 747)

## Roadmap

- [x] Core IRS protocol with ERC721 positions
- [x] Lending SDK with jump rate model
- [x] DEX SDK with constant product AMM
- [x] Margin and liquidation engines
- [x] Rate oracle with circuit breaker
- [x] 328-test suite (unit, integration, invariant)
- [x] Next.js 14 frontend with RainbowKit
- [x] Flow EVM testnet deployment (14 contracts live)
- [ ] Pyth oracle integration for FLOW/USD pricing
- [ ] Integration with IncrementFi and More.Markets rate feeds
- [ ] OrderBook and Automation modules on Flow
- [ ] Flow EVM mainnet deployment
- [ ] Professional security audit

## License

MIT
