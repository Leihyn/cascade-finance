// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/FixedPointMath.sol";
import "./PositionManager.sol";
import "../pricing/RateOracle.sol";

/// @title SettlementEngine
/// @author Kairos Protocol
/// @notice Handles periodic settlement of interest rate swap positions
/// @dev Calculates net payments and updates position PnL
contract SettlementEngine is ReentrancyGuard, Ownable {
    using FixedPointMath for uint256;
    using FixedPointMath for int256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                    PHASE 1: PARAMETER BOUNDS CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum settlement fee (5%)
    /// @dev From Leihyn security checklist - prevents fee exploitation
    uint256 public constant MAX_SETTLEMENT_FEE = 0.05e18;

    /// @notice Maximum close fee (0.5%)
    uint256 public constant MAX_CLOSE_FEE = 0.005e18;

    /// @notice Maximum keeper reward percentage (50% of fees)
    uint256 public constant MAX_KEEPER_REWARD = 0.5e18;

    /// @notice Minimum settlement interval (1 hour)
    uint256 public constant MIN_SETTLEMENT_INTERVAL = 1 hours;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Position manager contract
    PositionManager public immutable positionManager;

    /// @notice Rate oracle for floating rates
    RateOracle public immutable rateOracle;

    /// @notice Minimum time between settlements (in seconds)
    uint256 public settlementInterval;

    /// @notice Whether settlements are paused
    bool public paused;

    /// @notice Tracks last settlement time for each position
    mapping(uint256 => uint256) public lastSettlementTime;

    /// @notice Number of seconds in a year for rate calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL FEES
    //////////////////////////////////////////////////////////////*/

    /// @notice Settlement fee on positive PnL (percentage in WAD)
    /// @dev 1% = 0.01e18 - taken from profitable settlements
    uint256 public settlementFee = 0.01e18;

    /// @notice Close fee on closing positions (percentage of notional in WAD)
    /// @dev 0.02% = 0.0002e18
    uint256 public closeFee = 0.0002e18;

    /// @notice Total settlement fees collected
    uint256 public totalSettlementFeesCollected;

    /// @notice Total close fees collected
    uint256 public totalCloseFeesCollected;

    /// @notice Protocol fee recipient
    address public protocolFeeRecipient;

    /// @notice Keeper reward percentage (portion of settlement fee in WAD)
    /// @dev 10% = 0.10e18 means keeper gets 10% of settlement fees
    uint256 public keeperRewardPercentage = 0.10e18;

    /// @notice Total keeper rewards paid out
    uint256 public totalKeeperRewardsPaid;

    /// @notice Collateral token for fee collection
    IERC20 public immutable collateralToken;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionSettled(
        uint256 indexed positionId,
        int256 settlementAmount,
        uint256 floatingRate,
        uint256 fixedRate,
        uint256 periodDays
    );

    event PositionMatured(
        uint256 indexed positionId,
        int256 finalSettlement
    );

    event BatchSettlementCompleted(
        uint256 settledCount,
        uint256 failedCount
    );

    event SettlementIntervalUpdated(uint256 newInterval);
    event Paused(bool isPaused);

    event SettlementFeeCollected(uint256 indexed positionId, uint256 feeAmount);
    event CloseFeeCollected(uint256 indexed positionId, uint256 feeAmount);
    event KeeperRewardPaid(address indexed keeper, uint256 indexed positionId, uint256 reward);
    event SettlementFeeUpdated(uint256 newFee);
    event CloseFeeUpdated(uint256 newFee);
    event KeeperRewardPercentageUpdated(uint256 newPercentage);
    event ProtocolFeeRecipientUpdated(address newRecipient);
    event FeesWithdrawn(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error PositionNotActive(uint256 positionId);
    error SettlementTooSoon(uint256 positionId, uint256 nextSettlement);
    error PositionNotMatured(uint256 positionId);
    error ContractPaused();
    error InvalidInterval();
    error StaleOracleRate();
    error InvalidFee();
    error NoFeesToWithdraw();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _positionManager,
        address _rateOracle,
        uint256 _settlementInterval,
        address _collateralToken,
        address _protocolFeeRecipient
    ) Ownable(msg.sender) {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_protocolFeeRecipient == address(0)) revert ZeroAddress();

        positionManager = PositionManager(_positionManager);
        rateOracle = RateOracle(_rateOracle);
        settlementInterval = _settlementInterval > 0 ? _settlementInterval : 1 days;
        collateralToken = IERC20(_collateralToken);
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settle a single position
    /// @param positionId The position to settle
    /// @return settlementAmount The net settlement amount (positive = profit for position holder)
    function settle(uint256 positionId) external nonReentrant returns (int256 settlementAmount) {
        if (paused) revert ContractPaused();

        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert PositionNotActive(positionId);

        // Check if enough time has passed since last settlement
        uint256 lastSettled = lastSettlementTime[positionId];
        if (lastSettled == 0) {
            lastSettled = pos.startTime;
        }

        if (block.timestamp < lastSettled + settlementInterval) {
            revert SettlementTooSoon(positionId, lastSettled + settlementInterval);
        }

        // Calculate settlement
        int256 grossSettlement = _calculateSettlement(pos, lastSettled);

        // Collect fee from positive PnL only
        uint256 feeAmount = 0;
        if (grossSettlement > 0 && settlementFee > 0) {
            feeAmount = uint256(grossSettlement).wadMul(settlementFee);
            totalSettlementFeesCollected += feeAmount;
            settlementAmount = grossSettlement - int256(feeAmount);

            // Track keeper reward and pay immediately
            if (keeperRewardPercentage > 0) {
                uint256 keeperReward = feeAmount.wadMul(keeperRewardPercentage);
                totalKeeperRewardsPaid += keeperReward;
                // FIX C-04: Pay keeper via PositionManager (which holds the tokens)
                positionManager.payKeeper(msg.sender, keeperReward);
                // Reduce collected fees by keeper reward amount
                totalSettlementFeesCollected -= keeperReward;
                emit KeeperRewardPaid(msg.sender, positionId, keeperReward);
            }

            emit SettlementFeeCollected(positionId, feeAmount);
        } else {
            settlementAmount = grossSettlement;
        }

        // Update position PnL (net of fees)
        positionManager.updatePositionPnL(positionId, settlementAmount);

        // Update last settlement time
        lastSettlementTime[positionId] = block.timestamp;

        // Get rates for event
        uint256 floatingRate = rateOracle.getCurrentRate();
        uint256 periodDays = (block.timestamp - lastSettled) / 1 days;

        emit PositionSettled(
            positionId,
            settlementAmount,
            floatingRate,
            pos.fixedRate,
            periodDays
        );
    }

    /// @notice Settle multiple positions in a batch
    /// @param positionIds Array of position IDs to settle
    /// @return settledCount Number of successfully settled positions
    /// @return failedCount Number of positions that failed to settle
    function batchSettle(
        uint256[] calldata positionIds
    ) external nonReentrant returns (uint256 settledCount, uint256 failedCount) {
        if (paused) revert ContractPaused();

        for (uint256 i = 0; i < positionIds.length; i++) {
            // FIX H-02: Pass keeper address explicitly instead of using tx.origin
            try this.settleInternal(positionIds[i], msg.sender) {
                settledCount++;
            } catch {
                failedCount++;
            }
        }

        emit BatchSettlementCompleted(settledCount, failedCount);
    }

    /// @notice Internal settle function callable by this contract for batch operations
    /// @dev This is external so it can be called with try/catch.
    /// @param positionId Position to settle
    /// @param keeper Address to receive keeper rewards (FIX H-02: no more tx.origin)
    function settleInternal(uint256 positionId, address keeper) external {
        require(msg.sender == address(this), "Only internal");

        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert PositionNotActive(positionId);

        uint256 lastSettled = lastSettlementTime[positionId];
        if (lastSettled == 0) {
            lastSettled = pos.startTime;
        }

        if (block.timestamp < lastSettled + settlementInterval) {
            revert SettlementTooSoon(positionId, lastSettled + settlementInterval);
        }

        int256 grossSettlement = _calculateSettlement(pos, lastSettled);

        // Collect fee from positive PnL only
        int256 settlementAmount;
        uint256 feeAmount = 0;
        if (grossSettlement > 0 && settlementFee > 0) {
            feeAmount = uint256(grossSettlement).wadMul(settlementFee);
            totalSettlementFeesCollected += feeAmount;
            settlementAmount = grossSettlement - int256(feeAmount);

            // Track keeper reward and pay immediately
            if (keeperRewardPercentage > 0) {
                uint256 keeperReward = feeAmount.wadMul(keeperRewardPercentage);
                totalKeeperRewardsPaid += keeperReward;
                // FIX C-04 & H-02: Pay keeper via PositionManager using explicit parameter
                positionManager.payKeeper(keeper, keeperReward);
                totalSettlementFeesCollected -= keeperReward;
                emit KeeperRewardPaid(keeper, positionId, keeperReward);
            }

            emit SettlementFeeCollected(positionId, feeAmount);
        } else {
            settlementAmount = grossSettlement;
        }

        positionManager.updatePositionPnL(positionId, settlementAmount);
        lastSettlementTime[positionId] = block.timestamp;

        uint256 floatingRate = rateOracle.getCurrentRate();
        uint256 periodDays = (block.timestamp - lastSettled) / 1 days;

        emit PositionSettled(
            positionId,
            settlementAmount,
            floatingRate,
            pos.fixedRate,
            periodDays
        );
    }

    /// @notice Close a matured position
    /// @param positionId The position to close
    function closeMaturedPosition(uint256 positionId) external nonReentrant {
        if (paused) revert ContractPaused();

        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert PositionNotActive(positionId);
        if (block.timestamp < pos.maturity) revert PositionNotMatured(positionId);

        // Calculate final settlement from last settlement to maturity
        uint256 lastSettled = lastSettlementTime[positionId];
        if (lastSettled == 0) {
            lastSettled = pos.startTime;
        }

        int256 grossSettlement = _calculateSettlement(pos, lastSettled);

        // Apply settlement fee to positive PnL
        int256 finalSettlement;
        uint256 settlementFeeAmount = 0;
        if (grossSettlement > 0 && settlementFee > 0) {
            settlementFeeAmount = uint256(grossSettlement).wadMul(settlementFee);
            finalSettlement = grossSettlement - int256(settlementFeeAmount);
            totalSettlementFeesCollected += settlementFeeAmount;

            emit SettlementFeeCollected(positionId, settlementFeeAmount);
        } else {
            finalSettlement = grossSettlement;
        }

        // Calculate and collect close fee (percentage of notional)
        uint256 closeFeeAmount = 0;
        if (closeFee > 0) {
            closeFeeAmount = uint256(pos.notional).wadMul(closeFee);
            totalCloseFeesCollected += closeFeeAmount;

            // Deduct close fee from final settlement
            finalSettlement = finalSettlement - int256(closeFeeAmount);

            emit CloseFeeCollected(positionId, closeFeeAmount);
        }

        // Close position through position manager
        positionManager.closePosition(positionId, finalSettlement);

        emit PositionMatured(positionId, finalSettlement);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate pending settlement for a position
    /// @param positionId The position to check
    /// @return pendingAmount The pending settlement amount
    function getPendingSettlement(uint256 positionId) external view returns (int256 pendingAmount) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return 0;

        uint256 lastSettled = lastSettlementTime[positionId];
        if (lastSettled == 0) {
            lastSettled = pos.startTime;
        }

        return _calculateSettlement(pos, lastSettled);
    }

    /// @notice Check if a position is ready for settlement
    /// @param positionId The position to check
    /// @return isReady True if position can be settled
    function canSettle(uint256 positionId) external view returns (bool isReady) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return false;

        uint256 lastSettled = lastSettlementTime[positionId];
        if (lastSettled == 0) {
            lastSettled = pos.startTime;
        }

        return block.timestamp >= lastSettled + settlementInterval;
    }

    /// @notice Get time until next settlement is allowed
    /// @param positionId The position to check
    /// @return timeRemaining Seconds until settlement is allowed
    function getTimeToNextSettlement(uint256 positionId) external view returns (uint256 timeRemaining) {
        uint256 lastSettled = lastSettlementTime[positionId];
        PositionManager.Position memory pos = positionManager.getPosition(positionId);

        if (lastSettled == 0) {
            lastSettled = pos.startTime;
        }

        uint256 nextSettlement = lastSettled + settlementInterval;
        if (block.timestamp >= nextSettlement) return 0;
        return nextSettlement - block.timestamp;
    }

    /// @notice Preview what the settlement would be for given rates
    /// @param positionId The position
    /// @param floatingRate The floating rate to use (in WAD)
    /// @param periodSeconds The settlement period in seconds
    /// @return settlement The calculated settlement amount
    function previewSettlement(
        uint256 positionId,
        uint256 floatingRate,
        uint256 periodSeconds
    ) external view returns (int256 settlement) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        return _calculateSettlementWithRates(pos, floatingRate, periodSeconds);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the minimum settlement interval
    /// @param newInterval New interval in seconds (minimum 1 hour)
    function setSettlementInterval(uint256 newInterval) external onlyOwner {
        if (newInterval < MIN_SETTLEMENT_INTERVAL) revert InvalidInterval();
        settlementInterval = newInterval;
        emit SettlementIntervalUpdated(newInterval);
    }

    /// @notice Pause or unpause settlements
    /// @param _paused Whether to pause
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Update settlement fee
    /// @param _settlementFee New settlement fee in WAD (max 5% = 0.05e18)
    function setSettlementFee(uint256 _settlementFee) external onlyOwner {
        if (_settlementFee > MAX_SETTLEMENT_FEE) revert InvalidFee();
        settlementFee = _settlementFee;
        emit SettlementFeeUpdated(_settlementFee);
    }

    /// @notice Update close fee
    /// @param _closeFee New close fee in WAD (max 0.5% = 0.005e18)
    function setCloseFee(uint256 _closeFee) external onlyOwner {
        if (_closeFee > MAX_CLOSE_FEE) revert InvalidFee();
        closeFee = _closeFee;
        emit CloseFeeUpdated(_closeFee);
    }

    /// @notice Update keeper reward percentage
    /// @param _percentage New keeper reward percentage in WAD (max 50% = 0.5e18)
    function setKeeperRewardPercentage(uint256 _percentage) external onlyOwner {
        if (_percentage > MAX_KEEPER_REWARD) revert InvalidFee();
        keeperRewardPercentage = _percentage;
        emit KeeperRewardPercentageUpdated(_percentage);
    }

    /// @notice Update protocol fee recipient
    /// @param _recipient New fee recipient address
    function setProtocolFeeRecipient(address _recipient) external onlyOwner {
        if (_recipient == address(0)) revert ZeroAddress();
        protocolFeeRecipient = _recipient;
        emit ProtocolFeeRecipientUpdated(_recipient);
    }

    /// @notice Withdraw accumulated fees
    function withdrawFees() external onlyOwner {
        uint256 settlementFees = totalSettlementFeesCollected;
        uint256 closeFees = totalCloseFeesCollected;
        uint256 totalFees = settlementFees + closeFees;

        if (totalFees == 0) revert NoFeesToWithdraw();

        totalSettlementFeesCollected = 0;
        totalCloseFeesCollected = 0;

        collateralToken.safeTransfer(protocolFeeRecipient, totalFees);
        emit FeesWithdrawn(protocolFeeRecipient, totalFees);
    }

    /// @notice Get total fees collected
    /// @return settlementFees Total settlement fees
    /// @return closeFees Total close fees
    /// @return totalFees Combined total fees
    function getTotalFeesCollected() external view returns (
        uint256 settlementFees,
        uint256 closeFees,
        uint256 totalFees
    ) {
        settlementFees = totalSettlementFeesCollected;
        closeFees = totalCloseFeesCollected;
        totalFees = settlementFees + closeFees;
    }

    /// @notice Get keeper reward stats
    /// @return rewardPercentage Current keeper reward percentage
    /// @return totalPaid Total keeper rewards paid out
    function getKeeperStats() external view returns (
        uint256 rewardPercentage,
        uint256 totalPaid
    ) {
        rewardPercentage = keeperRewardPercentage;
        totalPaid = totalKeeperRewardsPaid;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate settlement amount for a position
    /// @param pos The position data
    /// @param lastSettled Last settlement timestamp
    /// @return settlement Net settlement amount
    function _calculateSettlement(
        PositionManager.Position memory pos,
        uint256 lastSettled
    ) internal view returns (int256 settlement) {
        // Get current floating rate from oracle
        uint256 floatingRate = rateOracle.getCurrentRate();

        // Calculate time period
        uint256 endTime = block.timestamp > pos.maturity ? pos.maturity : block.timestamp;
        uint256 periodSeconds = endTime - lastSettled;

        return _calculateSettlementWithRates(pos, floatingRate, periodSeconds);
    }

    /// @notice Calculate settlement with specific rates
    /// @param pos The position data
    /// @param floatingRate Current floating rate
    /// @param periodSeconds Time period in seconds
    /// @return settlement Net settlement amount
    function _calculateSettlementWithRates(
        PositionManager.Position memory pos,
        uint256 floatingRate,
        uint256 periodSeconds
    ) internal pure returns (int256 settlement) {
        if (periodSeconds == 0) return 0;

        // Calculate interest amounts for the period
        // Interest = Notional * Rate * (Period / Year)
        uint256 fixedInterest = uint256(pos.notional)
            .wadMul(pos.fixedRate)
            .wadMul(periodSeconds * 1e18 / SECONDS_PER_YEAR);

        uint256 floatingInterest = uint256(pos.notional)
            .wadMul(floatingRate)
            .wadMul(periodSeconds * 1e18 / SECONDS_PER_YEAR);

        // Calculate net payment based on position direction
        // Pay Fixed, Receive Floating: profit when floating > fixed
        // Pay Floating, Receive Fixed: profit when fixed > floating
        if (pos.isPayingFixed) {
            // Paying fixed rate, receiving floating rate
            // Settlement = FloatingInterest - FixedInterest
            settlement = int256(floatingInterest) - int256(fixedInterest);
        } else {
            // Paying floating rate, receiving fixed rate
            // Settlement = FixedInterest - FloatingInterest
            settlement = int256(fixedInterest) - int256(floatingInterest);
        }
    }
}
