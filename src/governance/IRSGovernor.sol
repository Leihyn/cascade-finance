// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title IRSGovernor
/// @notice Governance contract for the IRS protocol with timelock functionality
/// @dev Implements proposal creation, voting, and execution with time delays
contract IRSGovernor is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum voting power required to create a proposal
    uint256 public proposalThreshold;

    /// @notice Duration of voting period in seconds
    uint256 public votingPeriod;

    /// @notice Delay before voting starts after proposal creation
    uint256 public votingDelay;

    /// @notice Timelock delay for execution after proposal passes
    uint256 public timelockDelay;

    /// @notice Quorum required for proposal to pass (in basis points, 10000 = 100%)
    uint256 public quorumBps;

    /// @notice Total proposals created
    uint256 public proposalCount;

    /// @notice Mapping from proposal ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    /// @notice Mapping from proposal ID to execution time (for timelock)
    mapping(uint256 => uint256) public proposalEta;

    /// @notice Voting power of each address
    mapping(address => uint256) public votingPower;

    /// @notice Total voting power in the system
    uint256 public totalVotingPower;

    /// @notice Guardian address that can cancel proposals
    address public guardian;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );

    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingPowerChanged(address indexed account, uint256 oldPower, uint256 newPower);
    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _timelockDelay,
        uint256 _quorumBps
    ) Ownable(msg.sender) {
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        votingDelay = _votingDelay;
        timelockDelay = _timelockDelay;
        quorumBps = _quorumBps;
        guardian = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                            PROPOSAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new proposal
    /// @param targets Contract addresses to call
    /// @param values ETH values to send
    /// @param calldatas Function call data
    /// @param description Human-readable description
    /// @return proposalId The ID of the new proposal
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId) {
        require(
            votingPower[msg.sender] >= proposalThreshold,
            "Governor: below proposal threshold"
        );
        require(
            targets.length == values.length && targets.length == calldatas.length,
            "Governor: invalid proposal length"
        );
        require(targets.length > 0, "Governor: empty proposal");

        proposalId = ++proposalCount;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;
        proposal.description = description;
        proposal.startTime = block.timestamp + votingDelay;
        proposal.endTime = proposal.startTime + votingPeriod;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            calldatas,
            description,
            proposal.startTime,
            proposal.endTime
        );
    }

    /// @notice Cast a vote on a proposal
    /// @param proposalId The proposal ID
    /// @param support 0 = Against, 1 = For, 2 = Abstain
    function castVote(uint256 proposalId, uint8 support) external {
        require(state(proposalId) == ProposalState.Active, "Governor: voting is closed");
        require(support <= 2, "Governor: invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Governor: already voted");

        uint256 weight = votingPower[msg.sender];
        require(weight > 0, "Governor: no voting power");

        proposal.hasVoted[msg.sender] = true;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /// @notice Queue a successful proposal for execution
    /// @param proposalId The proposal ID
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor: proposal not successful"
        );

        uint256 eta = block.timestamp + timelockDelay;
        proposalEta[proposalId] = eta;

        emit ProposalQueued(proposalId, eta);
    }

    /// @notice Execute a queued proposal
    /// @param proposalId The proposal ID
    function execute(uint256 proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued, "Governor: not queued");
        require(block.timestamp >= proposalEta[proposalId], "Governor: timelock not expired");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                proposal.calldatas[i]
            );
            require(success, "Governor: execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancel a proposal (only guardian or proposer can cancel)
    /// @param proposalId The proposal ID
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == guardian || msg.sender == proposal.proposer,
            "Governor: not authorized"
        );
        require(!proposal.executed, "Governor: already executed");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current state of a proposal
    /// @param proposalId The proposal ID
    /// @return The current ProposalState
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        // Check if proposal passed
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalVotingPower * quorumBps) / 10000;

        if (totalVotes < quorumRequired || proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        }

        if (proposalEta[proposalId] == 0) {
            return ProposalState.Succeeded;
        }

        if (block.timestamp < proposalEta[proposalId]) {
            return ProposalState.Queued;
        }

        // Grace period of 14 days after ETA
        if (block.timestamp > proposalEta[proposalId] + 14 days) {
            return ProposalState.Expired;
        }

        return ProposalState.Queued;
    }

    /// @notice Check if an account has voted on a proposal
    function hasVoted(uint256 proposalId, address account) external view returns (bool) {
        return proposals[proposalId].hasVoted[account];
    }

    /// @notice Get proposal details
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            uint256 startTime,
            uint256 endTime
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.proposer, p.forVotes, p.againstVotes, p.abstainVotes, p.startTime, p.endTime);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set voting power for an account (admin only for now, will integrate with token)
    function setVotingPower(address account, uint256 power) external onlyOwner {
        uint256 oldPower = votingPower[account];
        totalVotingPower = totalVotingPower - oldPower + power;
        votingPower[account] = power;
        emit VotingPowerChanged(account, oldPower, power);
    }

    /// @notice Set the guardian address
    function setGuardian(address newGuardian) external onlyOwner {
        emit GuardianChanged(guardian, newGuardian);
        guardian = newGuardian;
    }

    /// @notice Update governance parameters
    function setParameters(
        uint256 _proposalThreshold,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _timelockDelay,
        uint256 _quorumBps
    ) external onlyOwner {
        proposalThreshold = _proposalThreshold;
        votingPeriod = _votingPeriod;
        votingDelay = _votingDelay;
        timelockDelay = _timelockDelay;
        quorumBps = _quorumBps;
    }

    /// @notice Receive ETH for proposal execution
    receive() external payable {}
}
