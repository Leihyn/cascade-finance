// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PositionManager.sol";

/// @title OrderBook
/// @author Kairos Protocol
/// @notice Matches pay-fixed orders with pay-floating orders
/// @dev Creates linked positions when orders are matched
contract OrderBook is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Order data
    struct Order {
        address trader;
        bool isPayingFixed;     // true = wants to pay fixed, false = wants to pay floating
        uint128 notional;       // desired notional amount
        uint128 minRate;        // minimum acceptable fixed rate (for pay-floating)
        uint128 maxRate;        // maximum acceptable fixed rate (for pay-fixed)
        uint128 margin;         // margin deposited
        uint40 maturityDays;    // desired maturity in days
        uint40 createdAt;       // order creation timestamp
        uint40 expiresAt;       // order expiration timestamp
        bool isActive;          // order status
    }

    /// @notice Matched position pair
    struct MatchedPair {
        uint256 payFixedPositionId;
        uint256 payFloatingPositionId;
        uint256 payFixedOrderId;
        uint256 payFloatingOrderId;
        uint128 matchedRate;
        uint128 matchedNotional;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Position manager contract
    PositionManager public immutable positionManager;

    /// @notice Collateral token
    IERC20 public immutable collateralToken;

    /// @notice Next order ID
    uint256 public nextOrderId;

    /// @notice Order data by ID
    mapping(uint256 => Order) public orders;

    /// @notice User's active order IDs
    mapping(address => uint256[]) public userOrders;

    /// @notice Matched pairs history
    MatchedPair[] public matchedPairs;

    /// @notice Minimum order duration (default 1 hour)
    uint256 public minOrderDuration = 1 hours;

    /// @notice Maximum order duration (default 7 days)
    uint256 public maxOrderDuration = 7 days;

    /// @notice Matching fee (percentage of notional in WAD)
    uint256 public matchingFee = 0.0001e18; // 0.01%

    /// @notice Total matching fees collected
    uint256 public totalMatchingFeesCollected;

    /// @notice Protocol fee recipient
    address public protocolFeeRecipient;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        bool isPayingFixed,
        uint128 notional,
        uint128 minRate,
        uint128 maxRate,
        uint40 maturityDays,
        uint40 expiresAt
    );

    event OrderCancelled(uint256 indexed orderId, address indexed trader);

    event OrdersMatched(
        uint256 indexed payFixedOrderId,
        uint256 indexed payFloatingOrderId,
        uint256 payFixedPositionId,
        uint256 payFloatingPositionId,
        uint128 matchedRate,
        uint128 matchedNotional
    );

    event OrderPartiallyFilled(
        uint256 indexed orderId,
        uint128 filledNotional,
        uint128 remainingNotional
    );

    event MatchingFeeUpdated(uint256 newFee);
    event FeesWithdrawn(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidNotional();
    error InvalidRate();
    error InvalidMaturity();
    error InvalidDuration();
    error InsufficientMargin();
    error OrderNotActive();
    error OrderExpired();
    error NotOrderOwner();
    error OrdersNotCompatible();
    error ZeroAddress();
    error NoFeesToWithdraw();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _positionManager,
        address _collateralToken,
        address _protocolFeeRecipient
    ) Ownable(msg.sender) {
        if (_positionManager == address(0)) revert ZeroAddress();
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_protocolFeeRecipient == address(0)) revert ZeroAddress();

        positionManager = PositionManager(_positionManager);
        collateralToken = IERC20(_collateralToken);
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                          ORDER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new order
    /// @param isPayingFixed True if trader wants to pay fixed rate
    /// @param notional Desired notional amount
    /// @param minRate Minimum acceptable fixed rate (for pay-floating orders)
    /// @param maxRate Maximum acceptable fixed rate (for pay-fixed orders)
    /// @param maturityDays Desired position maturity in days
    /// @param margin Margin to deposit
    /// @param duration How long the order stays active (in seconds)
    /// @return orderId The created order ID
    function createOrder(
        bool isPayingFixed,
        uint128 notional,
        uint128 minRate,
        uint128 maxRate,
        uint40 maturityDays,
        uint128 margin,
        uint256 duration
    ) external nonReentrant returns (uint256 orderId) {
        // Validate inputs
        if (notional == 0) revert InvalidNotional();
        if (minRate > maxRate) revert InvalidRate();
        if (duration < minOrderDuration || duration > maxOrderDuration) revert InvalidDuration();

        // Validate maturity
        if (maturityDays != 30 && maturityDays != 90 && maturityDays != 180 && maturityDays != 365) {
            revert InvalidMaturity();
        }

        // Check minimum margin (10% of notional)
        uint256 minMargin = (uint256(notional) * 10) / 100;
        if (margin < minMargin) revert InsufficientMargin();

        // Transfer margin from user
        collateralToken.safeTransferFrom(msg.sender, address(this), margin);

        // Create order
        orderId = nextOrderId++;

        orders[orderId] = Order({
            trader: msg.sender,
            isPayingFixed: isPayingFixed,
            notional: notional,
            minRate: minRate,
            maxRate: maxRate,
            margin: margin,
            maturityDays: maturityDays,
            createdAt: uint40(block.timestamp),
            expiresAt: uint40(block.timestamp + duration),
            isActive: true
        });

        userOrders[msg.sender].push(orderId);

        emit OrderCreated(
            orderId,
            msg.sender,
            isPayingFixed,
            notional,
            minRate,
            maxRate,
            maturityDays,
            uint40(block.timestamp + duration)
        );
    }

    /// @notice Cancel an active order and refund margin
    /// @param orderId The order to cancel
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];

        if (!order.isActive) revert OrderNotActive();
        if (order.trader != msg.sender) revert NotOrderOwner();

        // Mark as inactive
        order.isActive = false;

        // Refund margin
        collateralToken.safeTransfer(msg.sender, order.margin);

        emit OrderCancelled(orderId, msg.sender);
    }

    /// @notice Match two compatible orders
    /// @param payFixedOrderId Order ID of pay-fixed order
    /// @param payFloatingOrderId Order ID of pay-floating order
    function matchOrders(
        uint256 payFixedOrderId,
        uint256 payFloatingOrderId
    ) external nonReentrant {
        Order storage payFixedOrder = orders[payFixedOrderId];
        Order storage payFloatingOrder = orders[payFloatingOrderId];

        // Validate orders are active and not expired
        if (!payFixedOrder.isActive) revert OrderNotActive();
        if (!payFloatingOrder.isActive) revert OrderNotActive();
        if (block.timestamp > payFixedOrder.expiresAt) revert OrderExpired();
        if (block.timestamp > payFloatingOrder.expiresAt) revert OrderExpired();

        // Validate order directions
        if (!payFixedOrder.isPayingFixed) revert OrdersNotCompatible();
        if (payFloatingOrder.isPayingFixed) revert OrdersNotCompatible();

        // Validate maturity matches
        if (payFixedOrder.maturityDays != payFloatingOrder.maturityDays) revert OrdersNotCompatible();

        // Check rate compatibility
        // Pay-fixed wants rate <= maxRate
        // Pay-floating wants rate >= minRate
        // Compatible if: payFloatingOrder.minRate <= payFixedOrder.maxRate
        if (payFloatingOrder.minRate > payFixedOrder.maxRate) revert OrdersNotCompatible();

        // Calculate matched rate (midpoint)
        uint128 matchedRate = (payFixedOrder.maxRate + payFloatingOrder.minRate) / 2;

        // Calculate matched notional (minimum of both)
        uint128 matchedNotional = payFixedOrder.notional < payFloatingOrder.notional
            ? payFixedOrder.notional
            : payFloatingOrder.notional;

        // Calculate margins proportionally
        uint128 payFixedMargin = uint128((uint256(payFixedOrder.margin) * matchedNotional) / payFixedOrder.notional);
        uint128 payFloatingMargin = uint128((uint256(payFloatingOrder.margin) * matchedNotional) / payFloatingOrder.notional);

        // Calculate matching fee
        uint256 feePerSide = (uint256(matchedNotional) * matchingFee) / 1e18;
        totalMatchingFeesCollected += feePerSide * 2;

        // Deduct fees from margins
        payFixedMargin = payFixedMargin - uint128(feePerSide);
        payFloatingMargin = payFloatingMargin - uint128(feePerSide);

        // Approve position manager to spend margins
        collateralToken.approve(address(positionManager), payFixedMargin + payFloatingMargin);

        // Create positions via position manager
        // First, transfer margins to this contract's allowance for PM

        // Create pay-fixed position
        uint256 payFixedPositionId = _createPositionFor(
            payFixedOrder.trader,
            true, // isPayingFixed
            matchedNotional,
            matchedRate,
            payFixedOrder.maturityDays,
            payFixedMargin
        );

        // Create pay-floating position
        uint256 payFloatingPositionId = _createPositionFor(
            payFloatingOrder.trader,
            false, // isPayingFixed (pay floating)
            matchedNotional,
            matchedRate,
            payFloatingOrder.maturityDays,
            payFloatingMargin
        );

        // Update orders
        if (matchedNotional == payFixedOrder.notional) {
            payFixedOrder.isActive = false;
        } else {
            payFixedOrder.notional -= matchedNotional;
            payFixedOrder.margin -= payFixedMargin + uint128(feePerSide);
            emit OrderPartiallyFilled(payFixedOrderId, matchedNotional, payFixedOrder.notional);
        }

        if (matchedNotional == payFloatingOrder.notional) {
            payFloatingOrder.isActive = false;
        } else {
            payFloatingOrder.notional -= matchedNotional;
            payFloatingOrder.margin -= payFloatingMargin + uint128(feePerSide);
            emit OrderPartiallyFilled(payFloatingOrderId, matchedNotional, payFloatingOrder.notional);
        }

        // Record matched pair
        matchedPairs.push(MatchedPair({
            payFixedPositionId: payFixedPositionId,
            payFloatingPositionId: payFloatingPositionId,
            payFixedOrderId: payFixedOrderId,
            payFloatingOrderId: payFloatingOrderId,
            matchedRate: matchedRate,
            matchedNotional: matchedNotional
        }));

        emit OrdersMatched(
            payFixedOrderId,
            payFloatingOrderId,
            payFixedPositionId,
            payFloatingPositionId,
            matchedRate,
            matchedNotional
        );
    }

    /// @notice Find matching orders for a given order
    /// @param orderId The order to find matches for
    /// @return matchingOrderIds Array of compatible order IDs
    function findMatchingOrders(uint256 orderId) external view returns (uint256[] memory matchingOrderIds) {
        Order memory order = orders[orderId];
        if (!order.isActive) return new uint256[](0);

        // Count matches first
        uint256 matchCount = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (_areOrdersCompatible(orderId, i)) {
                matchCount++;
            }
        }

        // Populate array
        matchingOrderIds = new uint256[](matchCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (_areOrdersCompatible(orderId, i)) {
                matchingOrderIds[idx++] = i;
            }
        }
    }

    /// @notice Get all active orders
    /// @return payFixedOrders Array of active pay-fixed order IDs
    /// @return payFloatingOrders Array of active pay-floating order IDs
    function getActiveOrders() external view returns (
        uint256[] memory payFixedOrders,
        uint256[] memory payFloatingOrders
    ) {
        // Count active orders
        uint256 payFixedCount = 0;
        uint256 payFloatingCount = 0;

        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive && block.timestamp <= orders[i].expiresAt) {
                if (orders[i].isPayingFixed) {
                    payFixedCount++;
                } else {
                    payFloatingCount++;
                }
            }
        }

        // Populate arrays
        payFixedOrders = new uint256[](payFixedCount);
        payFloatingOrders = new uint256[](payFloatingCount);

        uint256 pfIdx = 0;
        uint256 pfloatIdx = 0;

        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive && block.timestamp <= orders[i].expiresAt) {
                if (orders[i].isPayingFixed) {
                    payFixedOrders[pfIdx++] = i;
                } else {
                    payFloatingOrders[pfloatIdx++] = i;
                }
            }
        }
    }

    /// @notice Get order details
    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    /// @notice Get user's orders
    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }

    /// @notice Get matched pairs count
    function getMatchedPairsCount() external view returns (uint256) {
        return matchedPairs.length;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update matching fee
    function setMatchingFee(uint256 _fee) external onlyOwner {
        if (_fee > 0.01e18) revert InvalidRate(); // Max 1%
        matchingFee = _fee;
        emit MatchingFeeUpdated(_fee);
    }

    /// @notice Update order duration limits
    function setOrderDurationLimits(uint256 _min, uint256 _max) external onlyOwner {
        minOrderDuration = _min;
        maxOrderDuration = _max;
    }

    /// @notice Withdraw collected fees
    function withdrawFees() external onlyOwner {
        uint256 amount = totalMatchingFeesCollected;
        if (amount == 0) revert NoFeesToWithdraw();

        totalMatchingFeesCollected = 0;
        collateralToken.safeTransfer(protocolFeeRecipient, amount);
        emit FeesWithdrawn(protocolFeeRecipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if two orders are compatible for matching
    function _areOrdersCompatible(uint256 orderId1, uint256 orderId2) internal view returns (bool) {
        if (orderId1 == orderId2) return false;

        Order memory order1 = orders[orderId1];
        Order memory order2 = orders[orderId2];

        // Both must be active and not expired
        if (!order1.isActive || !order2.isActive) return false;
        if (block.timestamp > order1.expiresAt || block.timestamp > order2.expiresAt) return false;

        // Must be opposite directions
        if (order1.isPayingFixed == order2.isPayingFixed) return false;

        // Must have same maturity
        if (order1.maturityDays != order2.maturityDays) return false;

        // Check rate compatibility
        Order memory payFixed = order1.isPayingFixed ? order1 : order2;
        Order memory payFloating = order1.isPayingFixed ? order2 : order1;

        return payFloating.minRate <= payFixed.maxRate;
    }

    /// @notice Create a position for a specific trader
    function _createPositionFor(
        address trader,
        bool isPayingFixed,
        uint128 notional,
        uint128 fixedRate,
        uint40 maturityDays,
        uint128 margin
    ) internal returns (uint256 positionId) {
        // Transfer margin to position manager
        collateralToken.safeTransfer(address(positionManager), margin);

        // The position manager will need to support creating positions on behalf of others
        // For now, we'll transfer the NFT after creation
        // This requires the OrderBook to be authorized on PositionManager

        // Note: This is a simplified approach. In production, you'd want
        // PositionManager to have an openPositionFor() function

        // For hackathon MVP, we'll have OrderBook open the position and transfer NFT
        positionId = positionManager.openPositionFor(
            trader,
            isPayingFixed,
            notional,
            fixedRate,
            maturityDays,
            margin
        );

    }
}
