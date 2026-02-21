"use client";

import { useState } from "react";
import { useAccount } from "wagmi";

interface GovernancePanelProps {
  contracts: any;
}

type ProposalState = "active" | "pending" | "succeeded" | "defeated" | "executed" | "queued";

interface Proposal {
  id: number;
  title: string;
  description: string;
  proposer: string;
  state: ProposalState;
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
  startTime: number;
  endTime: number;
}

export function GovernancePanel({ contracts }: GovernancePanelProps) {
  const { address } = useAccount();
  const [activeView, setActiveView] = useState<"proposals" | "create" | "delegate">("proposals");
  const [newProposal, setNewProposal] = useState({
    title: "",
    description: "",
    target: "",
    calldata: "",
  });

  // Mock data - would come from contract
  const governanceStats = {
    votingPower: "1,000",
    delegatedTo: "Self",
    totalProposals: 5,
    activeProposals: 2,
    quorum: "4%",
    votingPeriod: "3 days",
    timelockDelay: "2 days",
  };

  const proposals: Proposal[] = [
    {
      id: 1,
      title: "Increase Keeper Reward to 15%",
      description: "Increase keeper rewards from 10% to 15% to incentivize more settlements",
      proposer: "0x1234...5678",
      state: "active",
      forVotes: "125,000",
      againstVotes: "45,000",
      abstainVotes: "10,000",
      startTime: Date.now() - 86400000,
      endTime: Date.now() + 172800000,
    },
    {
      id: 2,
      title: "Add Aave V3 Rate Source",
      description: "Integrate Aave V3 as a new rate source for the oracle",
      proposer: "0xabcd...efgh",
      state: "succeeded",
      forVotes: "200,000",
      againstVotes: "25,000",
      abstainVotes: "5,000",
      startTime: Date.now() - 604800000,
      endTime: Date.now() - 432000000,
    },
    {
      id: 3,
      title: "Reduce Liquidation Bonus",
      description: "Reduce liquidation bonus from 5% to 3% to protect borrowers",
      proposer: "0x9876...5432",
      state: "defeated",
      forVotes: "50,000",
      againstVotes: "150,000",
      abstainVotes: "20,000",
      startTime: Date.now() - 1209600000,
      endTime: Date.now() - 1036800000,
    },
  ];

  const getStateColor = (state: ProposalState) => {
    switch (state) {
      case "active":
        return "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400";
      case "pending":
        return "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400";
      case "succeeded":
        return "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400";
      case "defeated":
        return "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400";
      case "executed":
        return "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400";
      case "queued":
        return "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400";
      default:
        return "bg-gray-100 text-gray-700";
    }
  };

  const handleVote = async (proposalId: number, support: number) => {
    console.log("Voting:", { proposalId, support });
    // Would call IRSGovernor.castVote()
  };

  const handleCreateProposal = async () => {
    console.log("Creating proposal:", newProposal);
    // Would call IRSGovernor.propose()
  };

  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4">
          <div className="text-sm text-gray-500 mb-1">Your Voting Power</div>
          <div className="text-xl font-bold">{governanceStats.votingPower}</div>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4">
          <div className="text-sm text-gray-500 mb-1">Delegated To</div>
          <div className="text-xl font-bold">{governanceStats.delegatedTo}</div>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4">
          <div className="text-sm text-gray-500 mb-1">Active Proposals</div>
          <div className="text-xl font-bold">{governanceStats.activeProposals}</div>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4">
          <div className="text-sm text-gray-500 mb-1">Quorum</div>
          <div className="text-xl font-bold">{governanceStats.quorum}</div>
        </div>
      </div>

      {/* Main Panel */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-6">
        {/* Tabs */}
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-lg p-1 mb-6 w-fit">
          {["proposals", "create", "delegate"].map((view) => (
            <button
              key={view}
              onClick={() => setActiveView(view as any)}
              className={`px-4 py-2 text-sm font-medium rounded-md capitalize transition-colors ${
                activeView === view
                  ? "bg-white dark:bg-gray-700 shadow-sm"
                  : "text-gray-500 hover:text-gray-700"
              }`}
            >
              {view}
            </button>
          ))}
        </div>

        {/* Proposals List */}
        {activeView === "proposals" && (
          <div className="space-y-4">
            {proposals.map((proposal) => (
              <div
                key={proposal.id}
                className="border border-gray-200 dark:border-gray-700 rounded-lg p-4"
              >
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm text-gray-500">#{proposal.id}</span>
                      <span
                        className={`px-2 py-0.5 text-xs font-medium rounded-full capitalize ${getStateColor(
                          proposal.state
                        )}`}
                      >
                        {proposal.state}
                      </span>
                    </div>
                    <h3 className="font-medium">{proposal.title}</h3>
                    <p className="text-sm text-gray-500 mt-1">{proposal.description}</p>
                  </div>
                </div>

                {/* Vote Progress */}
                <div className="mb-4">
                  <div className="flex justify-between text-xs text-gray-500 mb-1">
                    <span>For: {proposal.forVotes}</span>
                    <span>Against: {proposal.againstVotes}</span>
                  </div>
                  <div className="h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex">
                    <div
                      className="h-full bg-green-500"
                      style={{
                        width: `${
                          (parseInt(proposal.forVotes.replace(/,/g, "")) /
                            (parseInt(proposal.forVotes.replace(/,/g, "")) +
                              parseInt(proposal.againstVotes.replace(/,/g, "")))) *
                          100
                        }%`,
                      }}
                    />
                    <div
                      className="h-full bg-red-500"
                      style={{
                        width: `${
                          (parseInt(proposal.againstVotes.replace(/,/g, "")) /
                            (parseInt(proposal.forVotes.replace(/,/g, "")) +
                              parseInt(proposal.againstVotes.replace(/,/g, "")))) *
                          100
                        }%`,
                      }}
                    />
                  </div>
                </div>

                {/* Vote Buttons */}
                {proposal.state === "active" && (
                  <div className="flex gap-2">
                    <button
                      onClick={() => handleVote(proposal.id, 1)}
                      className="flex-1 py-2 bg-green-500 hover:bg-green-600 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                      For
                    </button>
                    <button
                      onClick={() => handleVote(proposal.id, 0)}
                      className="flex-1 py-2 bg-red-500 hover:bg-red-600 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                      Against
                    </button>
                    <button
                      onClick={() => handleVote(proposal.id, 2)}
                      className="flex-1 py-2 bg-gray-500 hover:bg-gray-600 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                      Abstain
                    </button>
                  </div>
                )}

                {proposal.state === "succeeded" && (
                  <button className="w-full py-2 bg-purple-500 hover:bg-purple-600 text-white text-sm font-medium rounded-lg transition-colors">
                    Queue for Execution
                  </button>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Create Proposal */}
        {activeView === "create" && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Title</label>
              <input
                type="text"
                value={newProposal.title}
                onChange={(e) => setNewProposal({ ...newProposal, title: e.target.value })}
                placeholder="Proposal title"
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Description</label>
              <textarea
                value={newProposal.description}
                onChange={(e) => setNewProposal({ ...newProposal, description: e.target.value })}
                placeholder="Describe your proposal..."
                rows={4}
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg resize-none"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Target Contract</label>
              <input
                type="text"
                value={newProposal.target}
                onChange={(e) => setNewProposal({ ...newProposal, target: e.target.value })}
                placeholder="0x..."
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg font-mono"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Calldata</label>
              <input
                type="text"
                value={newProposal.calldata}
                onChange={(e) => setNewProposal({ ...newProposal, calldata: e.target.value })}
                placeholder="0x..."
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg font-mono"
              />
            </div>
            <button
              onClick={handleCreateProposal}
              className="w-full py-3 bg-gradient-to-r from-indigo-500 to-purple-500 text-white font-medium rounded-lg hover:opacity-90 transition-opacity"
            >
              Create Proposal
            </button>
            <p className="text-sm text-gray-500 text-center">
              Requires {governanceStats.votingPower} voting power to create a proposal
            </p>
          </div>
        )}

        {/* Delegate */}
        {activeView === "delegate" && (
          <div className="space-y-4">
            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">Current Delegation</div>
              <div className="font-medium">{governanceStats.delegatedTo}</div>
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Delegate To</label>
              <input
                type="text"
                placeholder="0x... or ENS name"
                className="w-full px-4 py-3 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg font-mono"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <button className="py-3 bg-gradient-to-r from-indigo-500 to-purple-500 text-white font-medium rounded-lg hover:opacity-90 transition-opacity">
                Delegate
              </button>
              <button className="py-3 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-medium rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Self Delegate
              </button>
            </div>
            <div className="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg text-sm text-blue-700 dark:text-blue-300">
              <p>
                Delegating your voting power allows another address to vote on your behalf.
                You can reclaim it at any time by self-delegating.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
