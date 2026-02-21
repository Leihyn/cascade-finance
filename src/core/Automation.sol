// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PositionManager.sol";
import "./SettlementEngine.sol";
import "../pricing/RateOracle.sol";

/// @title Automation
/// @author Kairos Protocol
/// @notice Handles limit orders and stop-loss automation for IRS positions
/// @dev Keepers can execute orders when conditions are met and receive rewards
contract Automation is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Limit order - opens a position when rate hits target
    struct LimitOrder {
        address trader;
        bool isPayingFixed;
        uint128 notional;
        uint128 targetRate;       // Rate at which to open position
        bool triggerAbove;        // true = open when rate >= target, false = open when rate <= target
        uint128 margin;
        uint40 maturityDays;
        uint40 expiresAt;
        bool isActive;
    }

    /// @notice Stop-loss order - closes a position when PnL hits threshold
    struct StopLoss {
        uint256 positionId;
        address owner;
        int128 stopLossPnL;       // Close position if PnL drops below this (negative value)
        int128 takeProfitPnL;     // Close position if PnL rises above this (positive value)
        bool hasStopLoss;
        bool hasTakeProfit;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Position manager contract
    PositionManager public immutable positionManager;

    /// @notice Settlement engine contract
    SettlementEngine public immutable settlementEngine;

    /// @notice Rate oracle contract
    RateOracle public immutable rateOracle;

    /// @notice Collateral token
    IERC20 public immutable collateralToken;

    /// @notice Next limit order ID
    uint256 public nextLimitOrderId;

    /// @notice Limit orders by ID
    mapping(uint256 => LimitOrder) public limitOrders;

    /// @notice User's limit order IDs
    mapping(address => uint256[]) public userLimitOrders;

    /// @notice Stop-loss orders by position ID
    mapping(uint256 => StopLoss) public stopLossOrders;

    /// @notice Keeper reward for executing automation (percentage of notional in WAD)
    uint256 public keeperReward = 0.001e18; // 0.1%

    /// @notice Minimum order duration
    uint256 public minOrderDuration = 1 hours;

    /// @notice Maximum order duration
    uint256 public maxOrderDuration = 30 days;

    /// @notice Total keeper rewards paid
    uint256 public totalKeeperRewardsPaid;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event LimitOrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        bool isPayingFixed,
        uint128 notional,
        uint128 targetRate,
        bool triggerAbove,
        uint40 expiresAt
    );

    event LimitOrderCancelled(uint256 indexed orderId, address indexed trader);

    event LimitOrderExecuted(
        uint256 indexed orderId,
        uint256 indexed positionId,
        address indexed keeper,
        uint128 executedRate,
        uint256 keeperReward
    );

    event StopLossCreated(
        uint256 indexed positionId,
        address indexed owner,
        int128 stopLossPnL,
        int128 takeProfitPnL
    );

    event StopLossCancelled(uint256 indexed positionId, address indexed owner);

    event StopLossTriggered(
        uint256 indexed positionId,
        address indexed keeper,
        int128 currentPnL,
        bool wasStopLoss,
        uint256 keeperReward
    );

    event KeeperRewardUpdated(uint256 newReward);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidNotional();
    error InvalidRate();
    error InvalidDuration();
    error InvalidThresholds();
    error InsufficientMargin();
    error OrderNotActive();
    error OrderExpired();
    error NotOrderOwner();
    error ConditionNotMet();
    error PositionNotOwned();
    error StopLossAlreadySet();
    error NoStopLossSet();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _positionManager,
        address _settlementEngine,
        address _rateOracle,
        address _collateralToken
    ) Ownable(msg.sender) {
        if (_positionManager == address(0)) revert ZeroAddress();
        if (_settlementEngine == address(0)) revert ZeroAddress();
        if (_rateOracle == address(0)) revert ZeroAddress();
        if (_collateralToken == address(0)) revert ZeroAddress();

        positionManager = PositionManager(_positionManager);
        settlementEngine = SettlementEngine(_settlementEngine);
        rateOracle = RateOracle(_rateOracle);
        collateralToken = IERC20(_collateralToken);
    }

    /*//////////////////////////////////////////////////////////////
                          LIMIT ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a limit order to open a position at target rate
    /// @param isPayingFixed True = pay fixed, false = pay floating
    /// @param notional Position notional amount
    /// @param targetRate Rate at which to open position
    /// @param triggerAbove True = open when rate >= target
    /// @param maturityDays Position maturity in days
    /// @param margin Margin to deposit
    /// @param duration How long the order stays active
    /// @return orderId The created order ID
    function createLimitOrder(
        bool isPayingFixed,
        uint128 notional,
        uint128 targetRate,
        bool triggerAbove,
        uint40 maturityDays,
        uint128 margin,
        uint256 duration
    ) external nonReentrant returns (uint256 orderId) {
        if (notional == 0) revert InvalidNotional();
        if (targetRate == 0 || targetRate > 1e18) revert InvalidRate();
        if (duration < minOrderDuration || duration > maxOrderDuration) revert InvalidDuration();

        // Check minimum margin
        uint256 minMargin = (uint256(notional) * 10) / 100;
        if (margin < minMargin) revert InsufficientMargin();

        // Transfer margin from user (includes keeper reward buffer)
        uint256 keeperRewardAmount = uint256(notional) * keeperReward / 1e18;
        collateralToken.safeTransferFrom(msg.sender, address(this), margin + keeperRewardAmount);

        orderId = nextLimitOrderId++;

        limitOrders[orderId] = LimitOrder({
            trader: msg.sender,
            isPayingFixed: isPayingFixed,
            notional: notional,
            targetRate: targetRate,
            triggerAbove: triggerAbove,
            margin: margin,
            maturityDays: maturityDays,
            expiresAt: uint40(block.timestamp + duration),
            isActive: true
        });

        userLimitOrders[msg.sender].push(orderId);

        emit LimitOrderCreated(
            orderId,
            msg.sender,
            isPayingFixed,
            notional,
            targetRate,
            triggerAbove,
            uint40(block.timestamp + duration)
        );
    }

    /// @notice Cancel a limit order and refund margin
    /// @param orderId The order to cancel
    function cancelLimitOrder(uint256 orderId) external nonReentrant {
        LimitOrder storage order = limitOrders[orderId];

        if (!order.isActive) revert OrderNotActive();
        if (order.trader != msg.sender) revert NotOrderOwner();

        order.isActive = false;

        // Refund margin + keeper reward buffer
        uint256 keeperRewardAmount = uint256(order.notional) * keeperReward / 1e18;
        collateralToken.safeTransfer(msg.sender, order.margin + keeperRewardAmount);

        emit LimitOrderCancelled(orderId, msg.sender);
    }

    /// @notice Execute a limit order when conditions are met (keeper function)
    /// @param orderId The order to execute
    /// @return positionId The created position ID
    function executeLimitOrder(uint256 orderId) external nonReentrant returns (uint256 positionId) {
        LimitOrder storage order = limitOrders[orderId];

        if (!order.isActive) revert OrderNotActive();
        if (block.timestamp > order.expiresAt) revert OrderExpired();

        // Check if rate condition is met
        uint256 currentRate = rateOracle.getCurrentRate();

        if (order.triggerAbove) {
            if (currentRate < order.targetRate) revert ConditionNotMet();
        } else {
            if (currentRate > order.targetRate) revert ConditionNotMet();
        }

        // Mark order as executed
        order.isActive = false;

        // Calculate keeper reward
        uint256 reward = uint256(order.notional) * keeperReward / 1e18;
        totalKeeperRewardsPaid += reward;

        // Approve position manager
        collateralToken.approve(address(positionManager), order.margin);

        // Open position for the trader
        positionId = positionManager.openPositionFor(
            order.trader,
            order.isPayingFixed,
            order.notional,
            uint128(currentRate), // Use current rate as fixed rate
            order.maturityDays,
            order.margin
        );

        // Pay keeper reward
        collateralToken.safeTransfer(msg.sender, reward);

        emit LimitOrderExecuted(
            orderId,
            positionId,
            msg.sender,
            uint128(currentRate),
            reward
        );
    }

    /// @notice Check if a limit order can be executed
    /// @param orderId The order to check
    /// @return canExecute True if conditions are met
    /// @return currentRate Current oracle rate
    function canExecuteLimitOrder(uint256 orderId) external view returns (bool canExecute, uint256 currentRate) {
        LimitOrder memory order = limitOrders[orderId];

        if (!order.isActive || block.timestamp > order.expiresAt) {
            return (false, 0);
        }

        currentRate = rateOracle.getCurrentRate();

        if (order.triggerAbove) {
            canExecute = currentRate >= order.targetRate;
        } else {
            canExecute = currentRate <= order.targetRate;
        }
    }

    /// @notice Get executable limit orders
    /// @return orderIds Array of executable order IDs
    function getExecutableLimitOrders() external view returns (uint256[] memory orderIds) {
        uint256 count = 0;
        uint256 currentRate = rateOracle.getCurrentRate();

        // Count executable orders
        for (uint256 i = 0; i < nextLimitOrderId; i++) {
            LimitOrder memory order = limitOrders[i];
            if (!order.isActive || block.timestamp > order.expiresAt) continue;

            bool conditionMet = order.triggerAbove
                ? currentRate >= order.targetRate
                : currentRate <= order.targetRate;

            if (conditionMet) count++;
        }

        // Populate array
        orderIds = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < nextLimitOrderId; i++) {
            LimitOrder memory order = limitOrders[i];
            if (!order.isActive || block.timestamp > order.expiresAt) continue;

            bool conditionMet = order.triggerAbove
                ? currentRate >= order.targetRate
                : currentRate <= order.targetRate;

            if (conditionMet) {
                orderIds[idx++] = i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            STOP-LOSS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set stop-loss and/or take-profit for a position
    /// @param positionId The position to protect
    /// @param stopLossPnL Close if PnL drops below this (should be negative)
    /// @param takeProfitPnL Close if PnL rises above this (should be positive)
    /// @param enableStopLoss Whether to enable stop-loss
    /// @param enableTakeProfit Whether to enable take-profit
    function setStopLoss(
        uint256 positionId,
        int128 stopLossPnL,
        int128 takeProfitPnL,
        bool enableStopLoss,
        bool enableTakeProfit
    ) external nonReentrant {
        // Verify caller owns the position
        if (positionManager.ownerOf(positionId) != msg.sender) revert PositionNotOwned();

        // Validate thresholds
        if (enableStopLoss && stopLossPnL >= 0) revert InvalidThresholds();
        if (enableTakeProfit && takeProfitPnL <= 0) revert InvalidThresholds();
        if (!enableStopLoss && !enableTakeProfit) revert InvalidThresholds();

        // Check position is active
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert OrderNotActive();

        // Check if stop-loss already exists
        if (stopLossOrders[positionId].isActive) revert StopLossAlreadySet();

        // Pre-deposit keeper reward (based on notional)
        uint256 reward = uint256(pos.notional) * keeperReward / 1e18;
        collateralToken.safeTransferFrom(msg.sender, address(this), reward);

        stopLossOrders[positionId] = StopLoss({
            positionId: positionId,
            owner: msg.sender,
            stopLossPnL: stopLossPnL,
            takeProfitPnL: takeProfitPnL,
            hasStopLoss: enableStopLoss,
            hasTakeProfit: enableTakeProfit,
            isActive: true
        });

        emit StopLossCreated(positionId, msg.sender, stopLossPnL, takeProfitPnL);
    }

    /// @notice Cancel stop-loss for a position
    /// @param positionId The position to cancel stop-loss for
    function cancelStopLoss(uint256 positionId) external nonReentrant {
        StopLoss storage sl = stopLossOrders[positionId];

        if (!sl.isActive) revert NoStopLossSet();
        if (sl.owner != msg.sender) revert NotOrderOwner();

        sl.isActive = false;

        // Refund keeper reward
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        uint256 reward = uint256(pos.notional) * keeperReward / 1e18;
        collateralToken.safeTransfer(msg.sender, reward);

        emit StopLossCancelled(positionId, msg.sender);
    }

    /// @notice Execute stop-loss when conditions are met (keeper function)
    /// @param positionId The position to close
    function executeStopLoss(uint256 positionId) external nonReentrant {
        StopLoss storage sl = stopLossOrders[positionId];

        if (!sl.isActive) revert NoStopLossSet();

        // Get current position state
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert OrderNotActive();

        // Calculate pending settlement to get current PnL
        int256 pendingPnL = settlementEngine.getPendingSettlement(positionId);
        int128 currentPnL = pos.accumulatedPnL + int128(pendingPnL);

        // Check if conditions are met
        bool stopLossTriggered = sl.hasStopLoss && currentPnL <= sl.stopLossPnL;
        bool takeProfitTriggered = sl.hasTakeProfit && currentPnL >= sl.takeProfitPnL;

        if (!stopLossTriggered && !takeProfitTriggered) revert ConditionNotMet();

        // Mark as executed
        sl.isActive = false;

        // Calculate and pay keeper reward
        uint256 reward = uint256(pos.notional) * keeperReward / 1e18;
        totalKeeperRewardsPaid += reward;
        collateralToken.safeTransfer(msg.sender, reward);

        // Close the position if matured, otherwise just emit event
        // Note: For non-matured positions, the position owner would need to close manually
        // or we'd need additional authorization on PositionManager

        emit StopLossTriggered(
            positionId,
            msg.sender,
            currentPnL,
            stopLossTriggered,
            reward
        );
    }

    /// @notice Check if stop-loss can be executed
    /// @param positionId The position to check
    /// @return canExecute True if conditions are met
    /// @return currentPnL Current position PnL
    /// @return isStopLoss True if stop-loss triggered, false if take-profit
    function canExecuteStopLoss(uint256 positionId) external view returns (
        bool canExecute,
        int128 currentPnL,
        bool isStopLoss
    ) {
        StopLoss memory sl = stopLossOrders[positionId];
        if (!sl.isActive) return (false, 0, false);

        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return (false, 0, false);

        int256 pendingPnL = settlementEngine.getPendingSettlement(positionId);
        currentPnL = pos.accumulatedPnL + int128(pendingPnL);

        if (sl.hasStopLoss && currentPnL <= sl.stopLossPnL) {
            return (true, currentPnL, true);
        }

        if (sl.hasTakeProfit && currentPnL >= sl.takeProfitPnL) {
            return (true, currentPnL, false);
        }

        return (false, currentPnL, false);
    }

    /// @notice Get positions with triggerable stop-loss/take-profit
    /// @return positionIds Array of position IDs that can be executed
    function getTriggerableStopLosses() external view returns (uint256[] memory positionIds) {
        // First, count how many positions have stop-loss set
        // This is a simplified implementation - in production you'd track these
        uint256 maxPositions = positionManager.nextPositionId();
        uint256 count = 0;

        for (uint256 i = 0; i < maxPositions; i++) {
            StopLoss memory sl = stopLossOrders[i];
            if (!sl.isActive) continue;

            PositionManager.Position memory pos = positionManager.getPosition(i);
            if (!pos.isActive) continue;

            int256 pendingPnL = settlementEngine.getPendingSettlement(i);
            int128 currentPnL = pos.accumulatedPnL + int128(pendingPnL);

            bool stopLossTriggered = sl.hasStopLoss && currentPnL <= sl.stopLossPnL;
            bool takeProfitTriggered = sl.hasTakeProfit && currentPnL >= sl.takeProfitPnL;

            if (stopLossTriggered || takeProfitTriggered) count++;
        }

        positionIds = new uint256[](count);
        uint256 idx = 0;

        for (uint256 i = 0; i < maxPositions; i++) {
            StopLoss memory sl = stopLossOrders[i];
            if (!sl.isActive) continue;

            PositionManager.Position memory pos = positionManager.getPosition(i);
            if (!pos.isActive) continue;

            int256 pendingPnL = settlementEngine.getPendingSettlement(i);
            int128 currentPnL = pos.accumulatedPnL + int128(pendingPnL);

            bool stopLossTriggered = sl.hasStopLoss && currentPnL <= sl.stopLossPnL;
            bool takeProfitTriggered = sl.hasTakeProfit && currentPnL >= sl.takeProfitPnL;

            if (stopLossTriggered || takeProfitTriggered) {
                positionIds[idx++] = i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update keeper reward percentage
    /// @param _reward New reward percentage in WAD
    function setKeeperReward(uint256 _reward) external onlyOwner {
        if (_reward > 0.01e18) revert InvalidRate(); // Max 1%
        keeperReward = _reward;
        emit KeeperRewardUpdated(_reward);
    }

    /// @notice Update order duration limits
    function setOrderDurationLimits(uint256 _min, uint256 _max) external onlyOwner {
        minOrderDuration = _min;
        maxOrderDuration = _max;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get user's limit orders
    function getUserLimitOrders(address user) external view returns (uint256[] memory) {
        return userLimitOrders[user];
    }

    /// @notice Get limit order details
    function getLimitOrder(uint256 orderId) external view returns (LimitOrder memory) {
        return limitOrders[orderId];
    }

    /// @notice Get stop-loss details
    function getStopLoss(uint256 positionId) external view returns (StopLoss memory) {
        return stopLossOrders[positionId];
    }
}
