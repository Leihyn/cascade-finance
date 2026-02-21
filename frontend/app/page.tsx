"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useChainId } from "wagmi";
import { CONTRACT_ADDRESSES } from "@/lib/wagmi";
import { OpenPositionForm } from "@/components/OpenPositionForm";
import { PositionWizard } from "@/components/PositionWizard";
import { PositionsList } from "@/components/PositionsList";
import { ProtocolStats } from "@/components/ProtocolStats";
import { ActivityFeed } from "@/components/ActivityFeed";
import { TransactionHistory } from "@/components/TransactionHistory";
import { LendingPanel } from "@/components/LendingPanel";
import { SwapPanel } from "@/components/SwapPanel";
import { RateAMMPanel } from "@/components/RateAMMPanel";
import { GovernancePanel } from "@/components/GovernancePanel";
import { DashboardOverview } from "@/components/Dashboard";
import {
  TrendingUp,
  Landmark,
  ArrowLeftRight,
  BarChart3,
  Vote,
  Zap,
  Shield,
  Layers,
  ChevronRight,
  Sparkles,
  ExternalLink,
  LayoutDashboard,
} from "lucide-react";

type Tab = "dashboard" | "irs" | "lending" | "swap" | "amm" | "governance";

const tabs: { id: Tab; label: string; icon: React.ReactNode; description: string }[] = [
  { id: "dashboard", label: "Dashboard", icon: <LayoutDashboard className="w-5 h-5" />, description: "Overview & analytics" },
  { id: "irs", label: "Interest Rate Swaps", icon: <TrendingUp className="w-5 h-5" />, description: "Trade fixed vs floating rates" },
  { id: "lending", label: "Lending", icon: <Landmark className="w-5 h-5" />, description: "Supply & borrow assets" },
  { id: "swap", label: "Swap", icon: <ArrowLeftRight className="w-5 h-5" />, description: "Trade tokens instantly" },
  { id: "amm", label: "Rate AMM", icon: <BarChart3 className="w-5 h-5" />, description: "Provide rate liquidity" },
  { id: "governance", label: "Governance", icon: <Vote className="w-5 h-5" />, description: "Vote on proposals" },
];

const features = [
  {
    icon: <Zap className="w-6 h-6" />,
    title: "Lightning Fast",
    description: "Execute trades in seconds with optimized gas efficiency",
  },
  {
    icon: <Shield className="w-6 h-6" />,
    title: "Fully Audited",
    description: "Security-first approach with comprehensive testing",
  },
  {
    icon: <Layers className="w-6 h-6" />,
    title: "Composable DeFi",
    description: "Seamlessly integrated lending, DEX, and derivatives",
  },
];

export default function Home() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const contracts = CONTRACT_ADDRESSES[chainId];
  const [useWizard, setUseWizard] = useState(true);
  const [activeTab, setActiveTab] = useState<Tab>("dashboard");

  return (
    <>
      {/* Background */}
      <div className="bg-mesh" />

      <main className="min-h-screen relative">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-[--bg-primary] border-b border-[--border]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-4">
          <div className="flex justify-between items-center">
            {/* Logo */}
            <div className="flex items-center gap-4">
              <motion.div
                className="flex items-center gap-3"
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
              >
                <div className="relative">
                  <img src="/logo.jpeg" alt="Cascade Finance" className="w-10 h-10 rounded-lg object-cover" />
                </div>
                <div>
                  <h1 className="text-xl font-bold uppercase tracking-wider gradient-text">
                    CASCADE FINANCE
                  </h1>
                  <p className="text-xs text-[--text-muted]">Interest Rate Derivatives on Flow</p>
                </div>
              </motion.div>

              {/* Network Badge */}
              <motion.div
                className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full border border-[--border] bg-[--bg-secondary]"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.2 }}
              >
                <span className="pulse-dot" />
                <span className="text-xs text-[--text-secondary] uppercase">flow_evm</span>
              </motion.div>
            </div>

            {/* Connect Button */}
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.1 }}
            >
              <ConnectButton.Custom>
                {({ account, chain, openAccountModal, openConnectModal, mounted }) => {
                  const connected = mounted && account && chain;

                  return (
                    <div>
                      {!connected ? (
                        <button
                          onClick={openConnectModal}
                          className="neon-button px-6 py-2.5 text-sm font-semibold"
                        >
                          <span>Connect Wallet</span>
                        </button>
                      ) : (
                        <button
                          onClick={openAccountModal}
                          className="glass-button px-4 py-2.5 flex items-center gap-3"
                        >
                          <div className="pulse-dot" />
                          <span className="text-sm font-medium">
                            {account.displayName}
                          </span>
                        </button>
                      )}
                    </div>
                  );
                }}
              </ConnectButton.Custom>
            </motion.div>
          </div>
        </div>
      </header>

      {/* Tab Navigation */}
      {isConnected && (
        <motion.div
          className="border-b border-[--border] px-4 sm:px-6 bg-[--bg-secondary]"
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
        >
          <div className="max-w-7xl mx-auto">
            <nav className="flex gap-1 py-2 overflow-x-auto scrollbar-hide">
              {tabs.map((tab, index) => (
                <motion.button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`relative flex items-center gap-2 px-4 py-2 text-sm font-medium whitespace-nowrap transition-all duration-200 rounded-lg border ${
                    activeTab === tab.id
                      ? "text-[--bg-primary] bg-[--text-primary] border-[--text-primary] font-semibold"
                      : "text-[--text-secondary] bg-transparent border-transparent hover:text-[--text-primary] hover:bg-[--accent-subtle]"
                  }`}
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 * index }}
                >
                  <span className="relative z-10">{tab.icon}</span>
                  <span className="relative z-10 hidden sm:inline text-xs">{tab.label}</span>
                </motion.button>
              ))}
            </nav>
          </div>
        </motion.div>
      )}

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
        <AnimatePresence mode="wait">
          {!isConnected ? (
            /* Hero Section - Not Connected */
            <motion.div
              key="hero"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="py-12 sm:py-20"
            >
              {/* Hero Content */}
              <div className="text-center mb-16">
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 }}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[--accent-subtle] border border-[--border] mb-8"
                >
                  <Sparkles className="w-4 h-4 text-[--text-secondary]" />
                  <span className="text-sm text-[--text-secondary]">Full-Stack DeFi Protocol</span>
                </motion.div>

                <motion.h2
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.2 }}
                  className="text-4xl sm:text-5xl lg:text-6xl font-bold font-display mb-6"
                >
                  <span className="text-white">Institutional-Grade</span>
                  <br />
                  <span className="gradient-text">Interest Rate Markets</span>
                </motion.h2>

                <motion.p
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.3 }}
                  className="text-lg text-[--text-secondary] max-w-2xl mx-auto mb-10"
                >
                  Cascade Finance provides sophisticated financial instruments for managing interest rate exposure on Flow.
                  Access lending, trading, and derivative markets with sub-cent gas fees and instant finality.
                </motion.p>

                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.4 }}
                  className="flex flex-col sm:flex-row items-center justify-center gap-4"
                >
                  <ConnectButton.Custom>
                    {({ openConnectModal }) => (
                      <button
                        onClick={openConnectModal}
                        className="neon-button px-8 py-4 text-base font-semibold flex items-center gap-2 group"
                      >
                        <span>Launch App</span>
                        <ChevronRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                      </button>
                    )}
                  </ConnectButton.Custom>
                  <a
                    href="/docs"
                    className="neon-button-secondary px-8 py-4 text-base font-semibold rounded-xl flex items-center gap-2"
                  >
                    <span>Documentation</span>
                    <ChevronRight className="w-4 h-4" />
                  </a>
                </motion.div>
              </div>

              {/* Feature Cards */}
              <motion.div
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.5 }}
                className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-16"
              >
                {features.map((feature, index) => (
                  <motion.div
                    key={feature.title}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.6 + index * 0.1 }}
                    className="glass-card p-6 hover-lift"
                  >
                    <div className="w-12 h-12 rounded-xl bg-[--bg-tertiary] border border-[--border] flex items-center justify-center mb-4">
                      <div className="text-[--text-primary]">{feature.icon}</div>
                    </div>
                    <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
                    <p className="text-sm text-[--text-secondary]">{feature.description}</p>
                  </motion.div>
                ))}
              </motion.div>

              {/* Protocol Highlights */}
              <motion.div
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.8 }}
                className="glass-card p-8"
              >
                <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
                  {[
                    { label: "Smart Contracts", value: "14" },
                    { label: "Test Suite", value: "326" },
                    { label: "Chain", value: "Flow" },
                    { label: "Max Leverage", value: "20x" },
                  ].map((stat) => (
                    <div key={stat.label} className="text-center">
                      <div className="text-2xl sm:text-3xl font-bold font-display text-[--text-primary] mb-1">
                        {stat.value}
                      </div>
                      <div className="text-sm text-[--text-muted]">{stat.label}</div>
                    </div>
                  ))}
                </div>
              </motion.div>
            </motion.div>
          ) : (
            /* Connected - App Content */
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.3 }}
            >
              {/* Dashboard Tab */}
              {activeTab === "dashboard" && (
                <DashboardOverview contracts={contracts} />
              )}

              {/* IRS Tab */}
              {activeTab === "irs" && (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8">
                  <div className="lg:col-span-2 space-y-6">
                    {useWizard ? (
                      <PositionWizard
                        contracts={contracts}
                        onSwitchToAdvanced={() => setUseWizard(false)}
                      />
                    ) : (
                      <div className="relative">
                        <button
                          onClick={() => setUseWizard(true)}
                          className="absolute top-4 right-4 sm:top-6 sm:right-6 text-sm text-[--text-secondary] hover:text-white z-10 flex items-center gap-1"
                        >
                          <Sparkles className="w-4 h-4" />
                          Use Wizard
                        </button>
                        <OpenPositionForm contracts={contracts} />
                      </div>
                    )}
                    <PositionsList contracts={contracts} userAddress={address!} />
                    <TransactionHistory contracts={contracts} userAddress={address} />
                  </div>
                  <div className="space-y-6 order-first lg:order-last">
                    <ProtocolStats contracts={contracts} />
                    <ActivityFeed contracts={contracts} />
                  </div>
                </div>
              )}

              {/* Lending Tab */}
              {activeTab === "lending" && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8">
                  <LendingPanel contracts={contracts} />
                  <div className="space-y-6">
                    <div className="glass-card p-6">
                      <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                        <Landmark className="w-5 h-5 text-[--text-secondary]" />
                        How It Works
                      </h3>
                      <div className="space-y-4 text-sm text-[--text-secondary]">
                        <div className="flex gap-3 items-start">
                          <span className="w-6 h-6 rounded-full bg-[--bg-tertiary] border border-[--border] text-[--text-primary] flex items-center justify-center text-xs font-bold shrink-0">1</span>
                          <p>Supply USDC to earn interest from borrowers</p>
                        </div>
                        <div className="flex gap-3 items-start">
                          <span className="w-6 h-6 rounded-full bg-[--bg-tertiary] border border-[--border] text-[--text-primary] flex items-center justify-center text-xs font-bold shrink-0">2</span>
                          <p>Interest rates adjust based on pool utilization</p>
                        </div>
                        <div className="flex gap-3 items-start">
                          <span className="w-6 h-6 rounded-full bg-[--bg-tertiary] border border-[--border] text-[--text-primary] flex items-center justify-center text-xs font-bold shrink-0">3</span>
                          <p>Rates feed into the IRS protocol for trading</p>
                        </div>
                      </div>
                    </div>
                    <div className="glass-card p-6">
                      <h3 className="text-lg font-bold mb-2">Composability</h3>
                      <p className="text-sm text-[--text-secondary]">
                        The lending pool rates are automatically fed to the IRS protocol
                        through the CometRateAdapter, enabling interest rate speculation
                        based on real DeFi activity.
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {/* Swap Tab */}
              {activeTab === "swap" && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8">
                  <SwapPanel contracts={contracts} />
                  <div className="space-y-6">
                    <div className="glass-card p-6">
                      <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                        <ArrowLeftRight className="w-5 h-5 text-[--text-secondary]" />
                        AMM DEX
                      </h3>
                      <div className="space-y-4 text-sm text-[--text-secondary]">
                        <p>
                          Constant product (x*y=k) automated market maker inspired by
                          Uniswap V2.
                        </p>
                        <div className="grid grid-cols-2 gap-4">
                          <div className="stat-card">
                            <div className="text-xs text-[--text-muted]">Swap Fee</div>
                            <div className="text-xl font-bold font-display text-white">0.3%</div>
                          </div>
                          <div className="stat-card">
                            <div className="text-xs text-[--text-muted]">LP Tokens</div>
                            <div className="text-xl font-bold font-display text-white">ERC-20</div>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="glass-card p-6">
                      <h3 className="text-lg font-bold mb-4">Available Pairs</h3>
                      <div className="space-y-3">
                        <div className="flex items-center justify-between p-4 rounded-xl bg-[--accent-subtle] border border-[--border]">
                          <span className="font-medium">USDC / WFLOW</span>
                          <span className="badge badge-success">Active</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Rate AMM Tab */}
              {activeTab === "amm" && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8">
                  <RateAMMPanel contracts={contracts} />
                  <div className="space-y-6">
                    <div className="glass-card p-6">
                      <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                        <BarChart3 className="w-5 h-5 text-[--text-secondary]" />
                        Rate Trading AMM
                      </h3>
                      <div className="space-y-4 text-sm text-[--text-secondary]">
                        <p>
                          Trade fixed vs floating rates directly through the AMM.
                          Liquidity providers earn fees from rate swaps.
                        </p>
                        <div className="grid grid-cols-2 gap-4">
                          <div className="stat-card">
                            <div className="text-xs text-[--text-muted]">Trading Fee</div>
                            <div className="text-xl font-bold font-display text-white">0.3%</div>
                          </div>
                          <div className="stat-card">
                            <div className="text-xs text-[--text-muted]">LP Share</div>
                            <div className="text-xl font-bold font-display text-white">90%</div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Governance Tab */}
              {activeTab === "governance" && (
                <GovernancePanel contracts={contracts} />
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Footer */}
      <footer className="border-t border-[--border] px-6 py-6 mt-auto">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="text-[--text-muted] text-sm">
            Built on Flow EVM
          </div>
          <div className="flex items-center gap-4">
            <span className="text-xs text-[--text-muted]">Deployed on</span>
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-[--accent-subtle] border border-[--border]">
              <span className="pulse-dot" />
              <span className="text-xs text-[--text-secondary]">Flow EVM</span>
            </div>
          </div>
        </div>
      </footer>
      </main>
    </>
  );
}
