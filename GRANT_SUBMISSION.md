# Cascade Finance - Flow GrantDAO Round 2 Submission

## Track: DeFi

---

## Project Description

### What is Cascade Finance?

Cascade Finance is a composable interest rate derivatives protocol built natively on Flow EVM. It enables users to trade fixed vs floating interest rates -- a $500+ trillion market in traditional finance that is almost entirely absent from DeFi.

The protocol consists of three integrated components:

1. **Lending SDK** -- A Compound V3-style lending pool that generates real, dynamic interest rates based on supply/demand
2. **DEX SDK** -- A constant product AMM (Uniswap V2 architecture) for token swaps and liquidity provision
3. **Cascade IRS Protocol** -- The core product: interest rate swaps represented as ERC721 position NFTs, with automated hourly settlement, margin management, and liquidation

### Why does this matter for Flow?

Flow's DeFi ecosystem has DEXes (KittyPunch, Trado) and lending (IncrementFi, More.Markets), but **zero interest rate derivative products**. Cascade fills this gap and creates a new category of DeFi on Flow.

**Direct TVL impact**: Every IRS position requires USDC collateral locked in the protocol. The lending pool locks supplier deposits. The DEX locks LP tokens. Three TVL sources from one protocol.

**Network usage impact**: Automated hourly settlements generate consistent on-chain transactions. Each position open, settle, and close is an on-chain action. The protocol is designed to be high-frequency by nature.

**Why Flow specifically**: Interest rate derivatives require frequent settlement (hourly). On Ethereum L1, each settlement costs ~$30. On Flow, it costs fractions of a cent. This makes the product economically viable for retail-sized positions ($100-$10,000) -- exactly the demographic Flow serves.

---

## Milestone-Based Roadmap

### Milestone 1: Core Protocol Deployment (Weeks 1-2)
**Status: Complete**
- [x] 71 smart contracts across 3 integrated protocols
- [x] 328-test suite (unit, integration, invariant, fuzz, symbolic)
- [x] Full-stack deployment scripts for Flow EVM
- [x] Next.js 14 frontend with RainbowKit wallet integration
- [x] Flow EVM testnet deployment

**Deliverable**: Verified contracts on Flow EVM testnet, functional frontend

### Milestone 2: Flow Ecosystem Integration (Weeks 3-5)
- [ ] Integrate Pyth oracle for FLOW/USD and USDC/USD price feeds
- [ ] Build rate adapters for IncrementFi and More.Markets lending rates
- [ ] Enable OrderBook module for P2P rate matching
- [ ] Deploy Automation module (limit orders + stop-loss/take-profit)
- [ ] Build keeper bot infrastructure for automated settlements on Flow

**Deliverable**: Protocol pulling live rates from Flow DeFi ecosystem, automated settlement running

### Milestone 3: Production Launch (Weeks 6-9)
- [ ] Professional security audit (Cyfrin or equivalent)
- [ ] Flow EVM mainnet deployment
- [ ] Subgraph/indexer for position tracking and analytics
- [ ] Public API for rate data (benefits other Flow DeFi projects)
- [ ] Documentation site with integration guides

**Deliverable**: Audited, mainnet-live protocol with public rate API

### Milestone 4: Growth and Composability (Weeks 10-12)
- [ ] SDK for other Flow protocols to integrate IRS positions
- [ ] Rate AMM for passive liquidity provision to rate markets
- [ ] Governance module for protocol parameter management
- [ ] Partnership integrations with Flow wallets and aggregators
- [ ] Community education: tutorials, blog posts, Twitter threads

**Deliverable**: Composable SDK, growing TVL, active community

---

## Funding Request

**Total: 40,000 FLOW** across 4 milestones

| Milestone | FLOW | Purpose |
|-----------|------|---------|
| M1: Core Deployment | 5,000 | Testnet deployment, initial frontend hosting |
| M2: Ecosystem Integration | 12,000 | Oracle integration, keeper infrastructure, rate adapter development |
| M3: Production Launch | 15,000 | Security audit, mainnet deployment, indexing infrastructure |
| M4: Growth | 8,000 | SDK development, community building, partnership outreach |

---

## Fund Usage Plan

- **40% - Development**: Smart contract development, testing, frontend engineering
- **25% - Security**: Professional audit, bug bounty program setup
- **20% - Infrastructure**: RPC nodes, keeper bots, subgraph hosting, frontend deployment
- **15% - Growth**: Documentation, tutorials, community engagement, partnership development

---

## Success Metrics

| Metric | M1 (Week 2) | M2 (Week 5) | M3 (Week 9) | M4 (Week 12) |
|--------|-------------|-------------|-------------|--------------|
| Contracts deployed | Testnet | Testnet + adapters | Mainnet | Mainnet + SDK |
| Test coverage | 328 tests | 400+ tests | 400+ tests | 450+ tests |
| TVL | -- | -- | $50K target | $200K target |
| Active positions | Testnet only | Testnet only | 50+ | 200+ |
| Rate sources | 1 (internal) | 3+ (IncrementFi, More.Markets) | 3+ | 5+ |
| Weekly commits | 10+ | 10+ | 10+ | 7+ |

---

## Team

**Onatola Timilehin Faruq (Leihyn)** -- Solo builder

- Blockchain/Full Stack Engineer at DeFiConnectCredit
- UHI7 Graduate (Uniswap Hook Incubator) -- Built Sentiment dynamic fee hook (83 tests passing)
- Production experience integrating Aave V3, Uniswap V3/V4, Curve, GMX
- Built Sentinel: AI-powered smart contract security auditor (500+ exploit knowledge base)
- Code4rena competitive auditor (Olas audit)
- School of Solana (Ackee Blockchain) -- Cross-chain experience
- Prior projects: TerraCred (RWA lending on Hedera), TruthBounty (prediction market reputation on BNB), ComicPad (NFT marketplace on Hedera)

**GitHub**: github.com/Leihyn
**Twitter/X**: @leihyn

---

## Technical Details

### Smart Contract Architecture

| Layer | Contracts | Lines of Code |
|-------|-----------|---------------|
| Cascade IRS Core | PositionManager, SettlementEngine, OrderBook, Automation | ~2,500 |
| Risk Management | MarginEngine, LiquidationEngine | ~900 |
| Lending SDK | Comet, CometFactory, JumpRateModel | ~2,000 |
| DEX SDK | SwapFactory, SwapPair, SwapRouter | ~1,200 |
| Oracle & Adapters | RateOracle, CometRateAdapter | ~500 |
| Libraries & Mocks | FixedPointMath, MockERC20, MockPriceOracle | ~400 |
| **Total** | **71 contracts** | **~7,500** |

### Testing

- **328 tests** across unit, integration, invariant/fuzz (10,000 runs), and gas benchmarks
- Halmos symbolic execution for formal verification of critical paths
- Internal security review with all critical/high findings addressed

### Flow EVM Integration

- **Chain**: Flow EVM Testnet (545) / Mainnet (747)
- **Oracle**: Pyth Network (deployed on Flow at 0x2880aB155794e7179c9eE2e38200202908C17B43)
- **Tooling**: Foundry, OpenZeppelin, wagmi v2, RainbowKit
- **Verification**: FlowScan (Blockscout)

---

## Ecosystem Alignment

Cascade Finance directly benefits the Flow DeFi ecosystem:

1. **TVL Growth**: Three sources of locked value (lending deposits, DEX liquidity, IRS margin)
2. **Composability**: Other Flow protocols can use Cascade's rate data as a public good
3. **New Primitive**: First interest rate derivative on Flow -- opens an entirely new DeFi category
4. **Transaction Volume**: Hourly automated settlements generate consistent on-chain activity
5. **Rate Infrastructure**: Public rate oracle that any Flow DeFi protocol can consume

---

## Sustainability Plan

**Revenue model**: The protocol collects fees at three points:
- **Trading fee**: 0.05% of notional on position open
- **Settlement fee**: 1% of positive PnL on each settlement
- **Close fee**: 0.02% of notional on position close
- **DEX swap fee**: 0.3% per swap
- **Liquidation fee**: 2% of seized margin

At $1M TVL with moderate trading activity, projected monthly protocol revenue is $2,000-$5,000 USDC, growing linearly with TVL and position count.

**Long-term**: Governance token launch and DAO transition once protocol reaches $5M+ TVL.

---

## Links

- **GitHub**: [repository link]
- **Frontend**: [deployment link]
- **Flow EVM Testnet Contracts**: [FlowScan links after deployment]
- **Demo Video**: [to be recorded]
