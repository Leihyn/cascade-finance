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
import { ThemeSwitcher } from "@/components/ThemeSwitcher";
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
    color: "from-neon-cyan to-neon-blue",
  },
  {
    icon: <Shield className="w-6 h-6" />,
    title: "Fully Audited",
    description: "Security-first approach with comprehensive testing",
    color: "from-neon-purple to-neon-pink",
  },
  {
    icon: <Layers className="w-6 h-6" />,
    title: "Composable DeFi",
    description: "Seamlessly integrated lending, DEX, and derivatives",
    color: "from-neon-green to-neon-cyan",
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
      {/* Scanlines Background - Fixed */}
      <div className="bg-mesh" />

      <main className="min-h-screen relative">
        {/* Terminal Header */}
        <header className="sticky top-0 z-50 bg-black border-b-2 border-[--terminal-green] shadow-[0_0_20px_rgba(0,255,65,0.3)]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-4 font-mono">
          <div className="flex justify-between items-center">
            {/* Terminal Logo */}
            <div className="flex items-center gap-4">
              <motion.div
                className="flex items-center gap-3"
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
              >
                <div className="relative">
                  <div className="w-10 h-10 border-2 border-[--terminal-green] bg-[--bg-secondary] flex items-center justify-center shadow-[0_0_15px_rgba(0,255,65,0.4)]">
                    <span className="text-[--terminal-green] text-xl font-bold">$</span>
                  </div>
                </div>
                <div>
                  <h1 className="text-xl font-bold uppercase tracking-wider gradient-text">
                    CASCADE FINANCE
                  </h1>
                  <p className="text-xs text-[--text-comment]">$ /usr/bin/financial_services</p>
                </div>
              </motion.div>

              {/* Network Badge */}
              <motion.div
                className="hidden sm:flex items-center gap-2 px-3 py-1.5 border border-[--terminal-green-dark] bg-[--bg-secondary]"
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
                          <div className="w-2 h-2 rounded-full bg-neon-green animate-pulse" />
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

      {/* Terminal Tab Navigation */}
      {isConnected && (
        <motion.div
          className="border-b-2 border-[--terminal-green-dark] px-4 sm:px-6 bg-[--bg-secondary] font-mono"
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
        >
          <div className="max-w-7xl mx-auto">
            <div className="text-xs text-[--text-comment] pt-2 mb-1">$ ls /bank/services/</div>
            <nav className="flex gap-1 pb-2 overflow-x-auto scrollbar-hide">
              {tabs.map((tab, index) => (
                <motion.button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`relative flex items-center gap-2 px-4 py-2 text-sm font-medium whitespace-nowrap transition-all duration-300 uppercase tracking-wide border ${
                    activeTab === tab.id
                      ? "text-black bg-[--terminal-green] border-[--terminal-green] font-bold"
                      : "text-[--text-secondary] bg-black border-[--terminal-green-dark] hover:text-[--terminal-green] hover:border-[--terminal-green-dim]"
                  }`}
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 * index }}
                >
                  <span className="relative z-10 text-xs">{activeTab === tab.id ? '►' : '▪'}</span>
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
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 mb-8"
                >
                  <Sparkles className="w-4 h-4 text-neon-cyan" />
                  <span className="text-sm text-slate-300">Full-Stack DeFi Protocol</span>
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
                  className="text-lg text-slate-300 max-w-2xl mx-auto mb-10"
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
                    href="https://github.com"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="neon-button-secondary px-8 py-4 text-base font-semibold rounded-xl flex items-center gap-2"
                  >
                    <span>Documentation</span>
                    <ExternalLink className="w-4 h-4" />
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
                    <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${feature.color} flex items-center justify-center mb-4`}>
                      <div className="text-dark-950">{feature.icon}</div>
                    </div>
                    <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
                    <p className="text-sm text-slate-400">{feature.description}</p>
                  </motion.div>
                ))}
              </motion.div>

              {/* Stats Preview */}
              <motion.div
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.8 }}
                className="glass-card p-8"
              >
                <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
                  {[
                    { label: "Total Value Locked", value: "$2.4M" },
                    { label: "Active Positions", value: "1,247" },
                    { label: "Total Volume", value: "$12.8M" },
                    { label: "Unique Users", value: "892" },
                  ].map((stat, index) => (
                    <div key={stat.label} className="text-center">
                      <div className="text-2xl sm:text-3xl font-bold font-display gradient-text-cyan mb-1">
                        {stat.value}
                      </div>
                      <div className="text-sm text-slate-500">{stat.label}</div>
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
                          className="absolute top-4 right-4 sm:top-6 sm:right-6 text-sm text-slate-400 hover:text-white z-10 flex items-center gap-1"
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
                        <Landmark className="w-5 h-5 text-neon-cyan" />
                        How It Works
                      </h3>
                      <div className="space-y-4 text-sm text-slate-400">
                        <div className="flex gap-3 items-start">
                          <span className="w-6 h-6 rounded-full bg-neon-green/20 text-neon-green flex items-center justify-center text-xs font-bold shrink-0">1</span>
                          <p>Supply USDC to earn interest from borrowers</p>
                        </div>
                        <div className="flex gap-3 items-start">
                          <span className="w-6 h-6 rounded-full bg-neon-cyan/20 text-neon-cyan flex items-center justify-center text-xs font-bold shrink-0">2</span>
                          <p>Interest rates adjust based on pool utilization</p>
                        </div>
                        <div className="flex gap-3 items-start">
                          <span className="w-6 h-6 rounded-full bg-neon-purple/20 text-neon-purple flex items-center justify-center text-xs font-bold shrink-0">3</span>
                          <p>Rates feed into the IRS protocol for trading</p>
                        </div>
                      </div>
                    </div>
                    <div className="glass-card p-6 border-neon-purple/30">
                      <h3 className="text-lg font-bold mb-2 gradient-text-purple">Composability</h3>
                      <p className="text-sm text-slate-400">
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
                        <ArrowLeftRight className="w-5 h-5 text-neon-cyan" />
                        AMM DEX
                      </h3>
                      <div className="space-y-4 text-sm text-slate-400">
                        <p>
                          Constant product (x*y=k) automated market maker inspired by
                          Uniswap V2.
                        </p>
                        <div className="grid grid-cols-2 gap-4">
                          <div className="stat-card">
                            <div className="text-xs text-slate-500">Swap Fee</div>
                            <div className="text-xl font-bold font-display text-white">0.3%</div>
                          </div>
                          <div className="stat-card">
                            <div className="text-xs text-slate-500">LP Tokens</div>
                            <div className="text-xl font-bold font-display text-white">ERC-20</div>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="glass-card p-6">
                      <h3 className="text-lg font-bold mb-4">Available Pairs</h3>
                      <div className="space-y-3">
                        <div className="flex items-center justify-between p-4 rounded-xl bg-white/5 border border-white/10">
                          <span className="font-medium">USDC / WETH</span>
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
                        <BarChart3 className="w-5 h-5 text-neon-cyan" />
                        Rate Trading AMM
                      </h3>
                      <div className="space-y-4 text-sm text-slate-400">
                        <p>
                          Trade fixed vs floating rates directly through the AMM.
                          Liquidity providers earn fees from rate swaps.
                        </p>
                        <div className="grid grid-cols-2 gap-4">
                          <div className="stat-card">
                            <div className="text-xs text-slate-500">Trading Fee</div>
                            <div className="text-xl font-bold font-display text-white">0.3%</div>
                          </div>
                          <div className="stat-card">
                            <div className="text-xs text-slate-500">LP Share</div>
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

      {/* Theme Switcher */}
      <ThemeSwitcher />

      {/* Footer */}
      <footer className="border-t border-white/5 px-6 py-6 mt-auto">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="text-slate-500 text-sm">
            Built on Flow EVM
          </div>
          <div className="flex items-center gap-4">
            <span className="text-xs text-slate-600">Deployed on</span>
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10">
              <span className="pulse-dot" />
              <span className="text-xs text-slate-400">Flow EVM</span>
            </div>
          </div>
        </div>
      </footer>
      </main>
    </>
  );
}
