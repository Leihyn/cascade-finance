// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/FixedPointMath.sol";
import "../core/PositionManager.sol";
import "./MarginEngine.sol";

/// @title LiquidationEngine
/// @author Kairos Protocol
/// @notice Handles liquidation of undercollateralized positions
/// @dev Incentivizes liquidators with bonuses while protecting protocol solvency
contract LiquidationEngine is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using FixedPointMath for uint256;
    using FixedPointMath for int256;

    /*//////////////////////////////////////////////////////////////
                    PHASE 1: PARAMETER BOUNDS CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum liquidation bonus (10%)
    /// @dev Higher bonus creates perverse incentives; lower maintains solvency
    uint256 public constant MAX_LIQUIDATION_BONUS = 0.10e18;

    /// @notice Maximum protocol fee on liquidations (5%)
    uint256 public constant MAX_PROTOCOL_FEE = 0.05e18;

    /// @notice Minimum liquidation ratio (10%)
    /// @dev Ensures meaningful liquidations
    uint256 public constant MIN_LIQUIDATION_RATIO = 0.10e18;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Position manager contract
    PositionManager public immutable positionManager;

    /// @notice Margin engine for health calculations
    MarginEngine public immutable marginEngine;

    /// @notice Collateral token
    IERC20 public immutable collateralToken;

    /// @notice Liquidation bonus (percentage of margin given to liquidator)
    uint256 public liquidationBonus;

    /// @notice Protocol fee on liquidations (percentage of liquidated margin)
    uint256 public protocolFee;

    /// @notice Maximum percentage of margin that can be liquidated at once
    uint256 public maxLiquidationRatio;

    /// @notice Whether liquidations are paused
    bool public paused;

    /// @notice Protocol fee recipient
    address public protocolFeeRecipient;

    /// @notice Total fees collected
    uint256 public totalFeesCollected;

    /// @notice Total liquidations performed
    uint256 public totalLiquidations;

    /// @notice Total value liquidated
    uint256 public totalValueLiquidated;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        address indexed positionOwner,
        uint256 marginSeized,
        uint256 liquidatorReward,
        uint256 protocolFeeAmount
    );

    event PartialLiquidation(
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 marginSeized,
        uint256 remainingMargin
    );

    event LiquidationParametersUpdated(
        uint256 liquidationBonus,
        uint256 protocolFee,
        uint256 maxLiquidationRatio
    );

    event ProtocolFeeRecipientUpdated(address newRecipient);
    event Paused(bool isPaused);
    event FeesWithdrawn(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error PositionNotLiquidatable(uint256 positionId, uint256 healthFactor);
    error PositionNotActive(uint256 positionId);
    error ContractPaused();
    error InvalidParameters();
    error ZeroAddress();
    error NoFeesToWithdraw();
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _positionManager,
        address _marginEngine,
        address _collateralToken,
        address _protocolFeeRecipient
    ) Ownable(msg.sender) {
        if (_positionManager == address(0)) revert ZeroAddress();
        if (_marginEngine == address(0)) revert ZeroAddress();
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_protocolFeeRecipient == address(0)) revert ZeroAddress();

        positionManager = PositionManager(_positionManager);
        marginEngine = MarginEngine(_marginEngine);
        collateralToken = IERC20(_collateralToken);
        protocolFeeRecipient = _protocolFeeRecipient;

        // Default parameters
        liquidationBonus = 0.05e18; // 5% bonus to liquidator
        protocolFee = 0.02e18; // 2% protocol fee
        maxLiquidationRatio = 0.50e18; // Max 50% can be liquidated at once
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Liquidate an undercollateralized position
    /// @param positionId The position to liquidate
    /// @return marginSeized Amount of margin seized
    /// @return liquidatorReward Amount paid to liquidator
    function liquidate(
        uint256 positionId
    ) external nonReentrant returns (uint256 marginSeized, uint256 liquidatorReward) {
        if (paused) revert ContractPaused();

        // Check position is liquidatable
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert PositionNotActive(positionId);

        if (!marginEngine.isLiquidatable(positionId)) {
            uint256 hf = marginEngine.getHealthFactor(positionId);
            revert PositionNotLiquidatable(positionId, hf);
        }

        address positionOwner = positionManager.ownerOf(positionId);

        // Calculate seizure amounts
        (marginSeized, liquidatorReward) = _calculateLiquidationAmounts(pos);

        // Calculate protocol fee
        uint256 protocolFeeAmount = marginSeized.wadMul(protocolFee);

        // Seize margin from position
        positionManager.reduceMargin(positionId, uint128(marginSeized), address(this));

        // Pay liquidator
        collateralToken.safeTransfer(msg.sender, liquidatorReward);

        // Accumulate protocol fee
        totalFeesCollected += protocolFeeAmount;

        // Check if position should be fully closed
        PositionManager.Position memory posAfter = positionManager.getPosition(positionId);
        if (posAfter.margin == 0 || marginEngine.isLiquidatable(positionId)) {
            // Close the position completely
            positionManager.closePosition(positionId, 0);
        }

        // Update stats
        totalLiquidations++;
        totalValueLiquidated += marginSeized;

        emit PositionLiquidated(
            positionId,
            msg.sender,
            positionOwner,
            marginSeized,
            liquidatorReward,
            protocolFeeAmount
        );
    }

    /// @notice Partially liquidate a position
    /// @param positionId The position to liquidate
    /// @param amount Amount of margin to seize (must be <= maxLiquidationRatio * margin)
    /// @return liquidatorReward Amount paid to liquidator
    function partialLiquidate(
        uint256 positionId,
        uint256 amount
    ) external nonReentrant returns (uint256 liquidatorReward) {
        if (paused) revert ContractPaused();

        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert PositionNotActive(positionId);

        if (!marginEngine.isLiquidatable(positionId)) {
            uint256 hf = marginEngine.getHealthFactor(positionId);
            revert PositionNotLiquidatable(positionId, hf);
        }

        // Enforce max liquidation ratio
        uint256 maxSeizable = uint256(pos.margin).wadMul(maxLiquidationRatio);
        if (amount > maxSeizable) {
            amount = maxSeizable;
        }

        // FIX C-02: Calculate rewards using same corrected math as liquidate()
        uint256 protocolFeeAmount = amount.wadMul(protocolFee);
        uint256 effectiveBonus = liquidationBonus > protocolFee ? protocolFee : liquidationBonus;
        uint256 bonusAmount = amount.wadMul(effectiveBonus);
        liquidatorReward = amount - protocolFeeAmount + bonusAmount;
        if (liquidatorReward > amount) {
            liquidatorReward = amount;
        }

        // Seize margin
        positionManager.reduceMargin(positionId, uint128(amount), address(this));

        // Pay liquidator
        collateralToken.safeTransfer(msg.sender, liquidatorReward);

        // Accumulate protocol fee
        totalFeesCollected += protocolFeeAmount;

        // Update stats
        totalLiquidations++;
        totalValueLiquidated += amount;

        PositionManager.Position memory posAfter = positionManager.getPosition(positionId);

        emit PartialLiquidation(
            positionId,
            msg.sender,
            amount,
            posAfter.margin
        );
    }

    /// @notice Batch liquidate multiple positions
    /// @param positionIds Array of position IDs to liquidate
    /// @return liquidatedCount Number of successfully liquidated positions
    /// @return totalReward Total reward earned by liquidator
    function batchLiquidate(
        uint256[] calldata positionIds
    ) external nonReentrant returns (uint256 liquidatedCount, uint256 totalReward) {
        if (paused) revert ContractPaused();

        for (uint256 i = 0; i < positionIds.length; i++) {
            uint256 posId = positionIds[i];

            // Skip if not liquidatable
            if (!marginEngine.isLiquidatable(posId)) continue;

            PositionManager.Position memory pos = positionManager.getPosition(posId);
            if (!pos.isActive) continue;

            try this.liquidateInternal(posId, msg.sender) returns (
                uint256 reward
            ) {
                liquidatedCount++;
                totalReward += reward;
            } catch {
                // Skip failed liquidations
            }
        }
    }

    /// @notice Internal liquidation for batch operations
    /// @dev Called via external for try/catch support
    function liquidateInternal(
        uint256 positionId,
        address liquidator
    ) external returns (uint256 liquidatorReward) {
        require(msg.sender == address(this), "Only internal");

        PositionManager.Position memory pos = positionManager.getPosition(positionId);

        (uint256 marginSeized, uint256 reward) = _calculateLiquidationAmounts(pos);
        liquidatorReward = reward;

        uint256 protocolFeeAmount = marginSeized.wadMul(protocolFee);

        positionManager.reduceMargin(positionId, uint128(marginSeized), address(this));
        collateralToken.safeTransfer(liquidator, liquidatorReward);

        totalFeesCollected += protocolFeeAmount;
        totalLiquidations++;
        totalValueLiquidated += marginSeized;

        // Close if needed
        PositionManager.Position memory posAfter = positionManager.getPosition(positionId);
        if (posAfter.margin == 0) {
            positionManager.closePosition(positionId, 0);
        }

        address owner = positionManager.ownerOf(positionId);
        emit PositionLiquidated(
            positionId,
            liquidator,
            owner,
            marginSeized,
            liquidatorReward,
            protocolFeeAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if a position can be liquidated
    /// @param positionId The position to check
    /// @return canLiquidate True if position can be liquidated
    /// @return healthFactor Current health factor
    function canLiquidate(
        uint256 positionId
    ) external view returns (bool canLiquidate, uint256 healthFactor) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return (false, 0);

        healthFactor = marginEngine.getHealthFactor(positionId);
        canLiquidate = marginEngine.isLiquidatable(positionId);
    }

    /// @notice Preview liquidation for a position
    /// @param positionId The position to preview
    /// @return marginSeized Expected margin to be seized
    /// @return liquidatorReward Expected reward for liquidator
    /// @return protocolFeeAmount Expected protocol fee
    function previewLiquidation(
        uint256 positionId
    ) external view returns (
        uint256 marginSeized,
        uint256 liquidatorReward,
        uint256 protocolFeeAmount
    ) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return (0, 0, 0);

        (marginSeized, liquidatorReward) = _calculateLiquidationAmounts(pos);
        protocolFeeAmount = marginSeized.wadMul(protocolFee);
    }

    /// @notice Get liquidation statistics
    /// @return liquidations Total number of liquidations
    /// @return valueLiquidated Total value of liquidated positions
    /// @return feesCollected Total fees collected
    function getStats() external view returns (
        uint256 liquidations,
        uint256 valueLiquidated,
        uint256 feesCollected
    ) {
        return (totalLiquidations, totalValueLiquidated, totalFeesCollected);
    }

    /// @notice Find liquidatable positions in a range
    /// @param startId Starting position ID
    /// @param endId Ending position ID
    /// @return liquidatableIds Array of liquidatable position IDs
    function findLiquidatablePositions(
        uint256 startId,
        uint256 endId
    ) external view returns (uint256[] memory liquidatableIds) {
        // Count liquidatable positions
        uint256 count = 0;
        for (uint256 i = startId; i <= endId; i++) {
            if (marginEngine.isLiquidatable(i)) {
                count++;
            }
        }

        // Build array
        liquidatableIds = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = startId; i <= endId; i++) {
            if (marginEngine.isLiquidatable(i)) {
                liquidatableIds[idx++] = i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update liquidation parameters
    /// @dev Phase 1 Security: Uses constants for bounds validation
    /// @param _liquidationBonus New liquidation bonus (max 10%)
    /// @param _protocolFee New protocol fee (max 5%)
    /// @param _maxLiquidationRatio New max liquidation ratio (10%-100%)
    function setLiquidationParameters(
        uint256 _liquidationBonus,
        uint256 _protocolFee,
        uint256 _maxLiquidationRatio
    ) external onlyOwner {
        // Phase 1 Security: Stricter bounds using constants
        if (_liquidationBonus > MAX_LIQUIDATION_BONUS) revert InvalidParameters();
        if (_protocolFee > MAX_PROTOCOL_FEE) revert InvalidParameters();
        if (_maxLiquidationRatio < MIN_LIQUIDATION_RATIO || _maxLiquidationRatio > 1e18) {
            revert InvalidParameters();
        }

        liquidationBonus = _liquidationBonus;
        protocolFee = _protocolFee;
        maxLiquidationRatio = _maxLiquidationRatio;

        emit LiquidationParametersUpdated(_liquidationBonus, _protocolFee, _maxLiquidationRatio);
    }

    /// @notice Update protocol fee recipient
    /// @param _recipient New recipient address
    function setProtocolFeeRecipient(address _recipient) external onlyOwner {
        if (_recipient == address(0)) revert ZeroAddress();
        protocolFeeRecipient = _recipient;
        emit ProtocolFeeRecipientUpdated(_recipient);
    }

    /// @notice Pause or unpause liquidations
    /// @param _paused Whether to pause
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Withdraw accumulated protocol fees
    function withdrawFees() external onlyOwner {
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance == 0) revert NoFeesToWithdraw();

        collateralToken.safeTransfer(protocolFeeRecipient, balance);
        emit FeesWithdrawn(protocolFeeRecipient, balance);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate liquidation amounts
    /// @param pos The position data
    /// @return marginSeized Amount of margin to seize
    /// @return liquidatorReward Amount to pay liquidator
    function _calculateLiquidationAmounts(
        PositionManager.Position memory pos
    ) internal view returns (uint256 marginSeized, uint256 liquidatorReward) {
        // Seize up to maxLiquidationRatio of margin
        marginSeized = uint256(pos.margin).wadMul(maxLiquidationRatio);

        // Ensure we don't seize more than available
        if (marginSeized > pos.margin) {
            marginSeized = pos.margin;
        }

        // FIX C-02: Correct reward calculation to ensure solvency
        // Protocol takes its fee from seized amount
        uint256 protocolFeeAmount = marginSeized.wadMul(protocolFee);

        // Bonus comes from protocol's share (capped to fee amount)
        uint256 effectiveBonus = liquidationBonus > protocolFee ? protocolFee : liquidationBonus;
        uint256 bonusAmount = marginSeized.wadMul(effectiveBonus);

        // Liquidator gets: seized - protocolFee + bonus
        // Max possible: seized (when bonus == protocolFee)
        liquidatorReward = marginSeized - protocolFeeAmount + bonusAmount;

        // Safety cap: never exceed what we seized
        if (liquidatorReward > marginSeized) {
            liquidatorReward = marginSeized;
        }
    }
}
