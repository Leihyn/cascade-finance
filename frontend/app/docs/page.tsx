"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import {
  ArrowLeft,
  TrendingUp,
  Landmark,
  ArrowLeftRight,
  Shield,
  Zap,
  ExternalLink,
  BookOpen,
  Code2,
  GitBranch,
  Layers,
} from "lucide-react";

const sections = [
  {
    id: "overview",
    title: "Overview",
    icon: <BookOpen className="w-5 h-5" />,
  },
  {
    id: "architecture",
    title: "Architecture",
    icon: <Layers className="w-5 h-5" />,
  },
  {
    id: "irs",
    title: "Interest Rate Swaps",
    icon: <TrendingUp className="w-5 h-5" />,
  },
  {
    id: "lending",
    title: "Lending SDK",
    icon: <Landmark className="w-5 h-5" />,
  },
  {
    id: "dex",
    title: "DEX SDK",
    icon: <ArrowLeftRight className="w-5 h-5" />,
  },
  {
    id: "risk",
    title: "Risk Management",
    icon: <Shield className="w-5 h-5" />,
  },
  {
    id: "contracts",
    title: "Deployed Contracts",
    icon: <Code2 className="w-5 h-5" />,
  },
  {
    id: "quickstart",
    title: "Quick Start",
    icon: <Zap className="w-5 h-5" />,
  },
];

const contracts = [
  { name: "USDC", address: "0x2C5Bedd15f3d40Da729A68D852E4f436dA14ef79", category: "Tokens" },
  { name: "WFLOW", address: "0x83388045cab4caDc82ACfa99a63b17E6d4E5Cc87", category: "Tokens" },
  { name: "Comet", address: "0x15880a9E1719AAd5a37C99203c51C2E445651c94", category: "Lending SDK" },
  { name: "CometFactory", address: "0xb4A47F5D656C177be6cF4839551217f44cbb2Cb5", category: "Lending SDK" },
  { name: "JumpRateModel", address: "0xcC86944f5E7385cA6Df8EEC5d40957840cfdfbb2", category: "Lending SDK" },
  { name: "SwapFactory", address: "0x2716c3E427B33c78d01e06a5Ba19A673EB5d898b", category: "DEX SDK" },
  { name: "SwapRouter", address: "0x824d335886E8c516a121E2df59104F04cABAe30b", category: "DEX SDK" },
  { name: "PositionManager", address: "0x4A8705C1a7949F51DB589fA616f6f5c7ECf986e6", category: "Cascade IRS" },
  { name: "SettlementEngine", address: "0x29Be033fC3bDa9cbfc623848AEf7d38Cd6113d84", category: "Cascade IRS" },
  { name: "MarginEngine", address: "0x8061CCD94E4E233BDc602A46aB43681c6026Fee0", category: "Cascade IRS" },
  { name: "LiquidationEngine", address: "0x39618E21B20c18B54d9656d90Db7C4835Eb38b68", category: "Cascade IRS" },
  { name: "RateOracle", address: "0x914664B39D8DF72601086ebf903b741907d9cCD0", category: "Cascade IRS" },
  { name: "CometRateAdapter", address: "0xff0D1Ef082Aabe9bb00DC3e599bcc7d885C683fe", category: "Cascade IRS" },
  { name: "PriceOracle", address: "0x55Bd48C34441FEdA5c0D45a2400976fB933Abb7e", category: "Cascade IRS" },
];

function SectionHeading({ id, children }: { id: string; children: React.ReactNode }) {
  return (
    <h2 id={id} className="text-2xl font-bold text-[--text-primary] mb-4 pt-8 scroll-mt-24">
      {children}
    </h2>
  );
}

export default function DocsPage() {
  return (
    <div className="min-h-screen bg-[--bg-primary]">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-[--bg-primary] border-b border-[--border]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link href="/" className="flex items-center gap-2 text-[--text-secondary] hover:text-[--text-primary] transition-colors">
              <ArrowLeft className="w-4 h-4" />
              <span className="text-sm">Back to App</span>
            </Link>
            <div className="h-4 w-px bg-[--border]" />
            <h1 className="text-lg font-bold text-[--text-primary]">Documentation</h1>
          </div>
          <a
            href="https://github.com/Leihyn/cascade-finance"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-sm text-[--text-secondary] hover:text-[--text-primary] transition-colors"
          >
            <GitBranch className="w-4 h-4" />
            <span className="hidden sm:inline">GitHub</span>
            <ExternalLink className="w-3 h-3" />
          </a>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8 flex gap-8">
        {/* Sidebar */}
        <nav className="hidden lg:block w-56 shrink-0">
          <div className="sticky top-24 space-y-1">
            {sections.map((section) => (
              <a
                key={section.id}
                href={`#${section.id}`}
                className="flex items-center gap-3 px-3 py-2 text-sm text-[--text-secondary] hover:text-[--text-primary] hover:bg-[--accent-subtle] rounded-lg transition-colors"
              >
                {section.icon}
                {section.title}
              </a>
            ))}
          </div>
        </nav>

        {/* Content */}
        <motion.div
          className="flex-1 max-w-3xl"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {/* Overview */}
          <SectionHeading id="overview">Overview</SectionHeading>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <p>
              Interest rate swaps are a <strong className="text-[--text-primary]">$500+ trillion market</strong> in traditional finance.
              In DeFi, this market barely exists.
            </p>
            <p>
              A yield farmer deposits $50,000 into a lending pool expecting 5% APY. Two weeks later, rates crash to 1.2%.
              Months of expected yield gone, with no warning and no way to hedge.
            </p>
            <p>
              <strong className="text-[--text-primary]">Cascade Finance</strong> brings institutional-grade interest rate derivatives to Flow EVM.
              Three composable protocols working together: a lending pool that generates real rates, a DEX for token swaps,
              and an IRS protocol that lets you trade views on where rates are headed.
            </p>
          </div>

          {/* Architecture */}
          <SectionHeading id="architecture">Architecture</SectionHeading>
          <div className="glass-card p-6 mb-4 font-mono text-xs text-[--text-secondary] overflow-x-auto">
            <pre>{`+-------------------------------------------------------------+
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
|  |   Comet   |  |  +--------------+  |  |    Factory     |  |
|  |  (Pool)   +--+------------------+-+  |    Router      |  |
|  +-----------+  |                    |  |    Pairs       |  |
|  Interest Rates |                    |  +---------------+  |
+-----------------+                    +---------------------+`}</pre>
          </div>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <p>
              The lending pool generates real supply/borrow rates. The <strong className="text-[--text-primary]">CometRateAdapter</strong> bridges
              those rates into the IRS protocol&apos;s RateOracle. Users then open leveraged positions (up to 20x) betting on rate direction.
            </p>
            <p>
              Every position is minted as an <strong className="text-[--text-primary]">ERC-721 NFT</strong>, making positions transferable,
              tradeable, and composable with other DeFi protocols.
            </p>
          </div>

          {/* Interest Rate Swaps */}
          <SectionHeading id="irs">Interest Rate Swaps</SectionHeading>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <p>The core product. Two position types:</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="glass-card p-5">
                <h4 className="font-semibold text-[--text-primary] mb-2">Pay Fixed, Receive Floating</h4>
                <p className="text-xs text-[--text-secondary] mb-3">Bet that rates will rise.</p>
                <div className="text-xs space-y-1 text-[--text-muted]">
                  <p>You lock in a fixed rate (e.g. 5%)</p>
                  <p>You receive the current market rate</p>
                  <p>Profit when floating &gt; fixed</p>
                </div>
              </div>
              <div className="glass-card p-5">
                <h4 className="font-semibold text-[--text-primary] mb-2">Pay Floating, Receive Fixed</h4>
                <p className="text-xs text-[--text-secondary] mb-3">Bet that rates will fall.</p>
                <div className="text-xs space-y-1 text-[--text-muted]">
                  <p>You pay the current market rate</p>
                  <p>You receive a locked rate</p>
                  <p>Profit when fixed &gt; floating</p>
                </div>
              </div>
            </div>
            <div className="glass-card p-4">
              <h4 className="font-semibold text-[--text-primary] text-xs mb-2">Settlement Example</h4>
              <p className="text-xs text-[--text-muted]">
                A $10,000 position, fixed at 5%, current floating at 6%.
                <br />
                Hourly PnL (pay-fixed): +$10,000 x (6% - 5%) / 8760 = <strong className="text-[--text-primary]">+$1.14/hr</strong>
              </p>
            </div>
          </div>

          {/* Lending SDK */}
          <SectionHeading id="lending">Lending SDK</SectionHeading>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <p>
              Compound V3 (Comet) architecture. Users supply USDC to earn interest, or borrow against collateral.
              Interest rates follow a <strong className="text-[--text-primary]">jump rate model</strong>: gradual increase up to 80% utilization,
              then a sharp jump to incentivize repayment.
            </p>
            <div className="grid grid-cols-3 gap-4">
              <div className="stat-card text-center">
                <div className="text-xs text-[--text-muted] mb-1">Base Rate</div>
                <div className="text-lg font-bold text-[--text-primary]">2%</div>
              </div>
              <div className="stat-card text-center">
                <div className="text-xs text-[--text-muted] mb-1">Kink</div>
                <div className="text-lg font-bold text-[--text-primary]">80%</div>
              </div>
              <div className="stat-card text-center">
                <div className="text-xs text-[--text-muted] mb-1">Jump Multiplier</div>
                <div className="text-lg font-bold text-[--text-primary]">5x</div>
              </div>
            </div>
          </div>

          {/* DEX SDK */}
          <SectionHeading id="dex">DEX SDK</SectionHeading>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <p>
              Constant product (x*y=k) AMM inspired by Uniswap V2. Provides on-chain token swaps
              with 0.3% fee. LP tokens are standard ERC-20.
            </p>
            <p>
              The DEX enables token conversion needed for margin deposits and position management
              within the Cascade ecosystem.
            </p>
          </div>

          {/* Risk Management */}
          <SectionHeading id="risk">Risk Management</SectionHeading>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="glass-card p-5">
                <h4 className="font-semibold text-[--text-primary] mb-2">Margin Engine</h4>
                <ul className="text-xs space-y-1 text-[--text-muted]">
                  <li>10% initial margin requirement</li>
                  <li>5% maintenance margin</li>
                  <li>Maximum 20x leverage</li>
                  <li>Health factor monitoring</li>
                </ul>
              </div>
              <div className="glass-card p-5">
                <h4 className="font-semibold text-[--text-primary] mb-2">Liquidation Engine</h4>
                <ul className="text-xs space-y-1 text-[--text-muted]">
                  <li>5% bonus to liquidators</li>
                  <li>Partial liquidation support</li>
                  <li>Automated health checks</li>
                  <li>ReentrancyGuard protected</li>
                </ul>
              </div>
            </div>
            <div className="glass-card p-5">
              <h4 className="font-semibold text-[--text-primary] mb-2">Rate Oracle Circuit Breaker</h4>
              <p className="text-xs text-[--text-muted]">
                The RateOracle aggregates multiple rate sources, filters outliers via median calculation,
                and trips a circuit breaker on &gt;5x rate changes to prevent manipulation.
              </p>
            </div>
          </div>

          {/* Deployed Contracts */}
          <SectionHeading id="contracts">Deployed Contracts</SectionHeading>
          <p className="text-sm text-[--text-secondary] mb-4">
            Flow EVM Testnet (Chain ID: 545). All contracts verified on FlowScan.
          </p>
          <div className="space-y-6">
            {["Tokens", "Lending SDK", "DEX SDK", "Cascade IRS"].map((category) => (
              <div key={category}>
                <h4 className="text-xs font-semibold text-[--text-muted] uppercase tracking-wider mb-2">{category}</h4>
                <div className="space-y-1">
                  {contracts
                    .filter((c) => c.category === category)
                    .map((contract) => (
                      <div key={contract.name} className="flex items-center justify-between p-3 rounded-lg bg-[--bg-secondary] border border-[--border]">
                        <span className="text-sm font-medium text-[--text-primary]">{contract.name}</span>
                        <a
                          href={`https://evm-testnet.flowscan.io/address/${contract.address}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1.5 text-xs text-[--text-muted] hover:text-[--text-primary] font-mono transition-colors"
                        >
                          {contract.address.slice(0, 6)}...{contract.address.slice(-4)}
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      </div>
                    ))}
                </div>
              </div>
            ))}
          </div>

          {/* Quick Start */}
          <SectionHeading id="quickstart">Quick Start</SectionHeading>
          <div className="space-y-4 text-[--text-secondary] text-sm leading-relaxed">
            <div className="glass-card p-5">
              <h4 className="font-semibold text-[--text-primary] mb-3">Smart Contracts</h4>
              <div className="font-mono text-xs bg-[--bg-primary] border border-[--border] rounded-lg p-4 space-y-1 text-[--text-secondary]">
                <p className="text-[--text-muted]"># Clone and build</p>
                <p>git clone https://github.com/Leihyn/cascade-finance.git</p>
                <p>cd cascade-finance</p>
                <p>forge install</p>
                <p>&nbsp;</p>
                <p className="text-[--text-muted]"># Run 326 tests</p>
                <p>forge test</p>
                <p>&nbsp;</p>
                <p className="text-[--text-muted]"># Deploy to Flow EVM Testnet</p>
                <p>forge script script/DeployFull.s.sol:DeployFull \</p>
                <p>  --rpc-url https://testnet.evm.nodes.onflow.org \</p>
                <p>  --broadcast --private-key $PRIVATE_KEY</p>
              </div>
            </div>
            <div className="glass-card p-5">
              <h4 className="font-semibold text-[--text-primary] mb-3">Frontend</h4>
              <div className="font-mono text-xs bg-[--bg-primary] border border-[--border] rounded-lg p-4 space-y-1 text-[--text-secondary]">
                <p>cd frontend</p>
                <p>npm install</p>
                <p>npm run dev</p>
                <p className="text-[--text-muted]"># Open http://localhost:3000</p>
              </div>
            </div>
            <div className="glass-card p-5">
              <h4 className="font-semibold text-[--text-primary] mb-3">Get Testnet FLOW</h4>
              <p className="text-xs text-[--text-muted] mb-2">Fund your wallet to interact with the protocol on testnet.</p>
              <a
                href="https://faucet.flow.com/fund-account"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 text-xs text-[--text-primary] hover:underline"
              >
                Flow Faucet
                <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          </div>

          {/* Tech Stack */}
          <div className="mt-12 mb-8 glass-card p-6">
            <h3 className="text-sm font-semibold text-[--text-primary] mb-4">Tech Stack</h3>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-xs">
              <div>
                <div className="text-[--text-muted] mb-1">Contracts</div>
                <div className="text-[--text-primary]">Solidity 0.8.24</div>
                <div className="text-[--text-muted]">Foundry, OpenZeppelin</div>
              </div>
              <div>
                <div className="text-[--text-muted] mb-1">Frontend</div>
                <div className="text-[--text-primary]">Next.js 14</div>
                <div className="text-[--text-muted]">wagmi v2, RainbowKit</div>
              </div>
              <div>
                <div className="text-[--text-muted] mb-1">Testing</div>
                <div className="text-[--text-primary]">326 tests</div>
                <div className="text-[--text-muted]">Unit, fuzz, invariant</div>
              </div>
              <div>
                <div className="text-[--text-muted] mb-1">Network</div>
                <div className="text-[--text-primary]">Flow EVM</div>
                <div className="text-[--text-muted]">Chain 545 (testnet)</div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
