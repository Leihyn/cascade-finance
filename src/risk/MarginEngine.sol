// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/FixedPointMath.sol";
import "../core/PositionManager.sol";
import "../pricing/RateOracle.sol";

/// @title MarginEngine
/// @author Kairos Protocol
/// @notice Calculates margin requirements and health factors for positions
/// @dev Determines when positions become undercollateralized
contract MarginEngine is Ownable {
    using FixedPointMath for uint256;
    using FixedPointMath for int256;

    /*//////////////////////////////////////////////////////////////
                    PHASE 1: PARAMETER BOUNDS CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum initial margin ratio (5%)
    /// @dev Prevents excessive leverage
    uint256 public constant MIN_INITIAL_MARGIN_RATIO = 0.05e18;

    /// @notice Maximum initial margin ratio (50%)
    uint256 public constant MAX_INITIAL_MARGIN_RATIO = 0.50e18;

    /// @notice Minimum maintenance margin ratio (2.5%)
    uint256 public constant MIN_MAINTENANCE_MARGIN_RATIO = 0.025e18;

    /// @notice Maximum leverage allowed (20x)
    /// @dev Higher leverage increases systemic risk
    uint256 public constant ABSOLUTE_MAX_LEVERAGE = 20e18;

    /// @notice Maximum rate volatility factor (25%)
    uint256 public constant MAX_VOLATILITY_FACTOR = 0.25e18;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Position manager contract
    PositionManager public immutable positionManager;

    /// @notice Rate oracle for price impact calculations
    RateOracle public immutable rateOracle;

    /// @notice Initial margin ratio (10% of notional)
    uint256 public initialMarginRatio;

    /// @notice Maintenance margin ratio (5% of notional)
    uint256 public maintenanceMarginRatio;

    /// @notice Liquidation threshold (below this health factor, position can be liquidated)
    uint256 public liquidationThreshold;

    /// @notice Maximum allowed leverage
    uint256 public maxLeverage;

    /// @notice Rate volatility factor for margin calculations
    uint256 public rateVolatilityFactor;

    /// @notice Number of seconds in a year for rate calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarginParametersUpdated(
        uint256 initialMarginRatio,
        uint256 maintenanceMarginRatio,
        uint256 liquidationThreshold
    );

    event MaxLeverageUpdated(uint256 newMaxLeverage);
    event RateVolatilityFactorUpdated(uint256 newFactor);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidRatio();
    error InvalidThreshold();
    error InvalidLeverage();
    error PositionNotActive(uint256 positionId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _positionManager,
        address _rateOracle
    ) Ownable(msg.sender) {
        positionManager = PositionManager(_positionManager);
        rateOracle = RateOracle(_rateOracle);

        // Default parameters
        initialMarginRatio = 0.10e18; // 10%
        maintenanceMarginRatio = 0.05e18; // 5%
        liquidationThreshold = 1e18; // Health factor of 1.0
        maxLeverage = 10e18; // 10x max leverage
        rateVolatilityFactor = 0.02e18; // 2% rate volatility assumption
    }

    /*//////////////////////////////////////////////////////////////
                          MARGIN CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate required initial margin for a position
    /// @param notional The notional amount
    /// @param maturityDays Time to maturity in days
    /// @return requiredMargin Minimum initial margin required
    function calculateInitialMargin(
        uint256 notional,
        uint256 maturityDays
    ) external view returns (uint256 requiredMargin) {
        // Base margin = notional * initial margin ratio
        uint256 baseMargin = notional.wadMul(initialMarginRatio);

        // Adjust for maturity (longer = higher margin due to rate risk)
        uint256 maturityFactor = _getMaturityFactor(maturityDays);
        uint256 adjustedMargin = baseMargin.wadMul(maturityFactor);

        // Adjust for current rate volatility
        uint256 volatilityAdjustment = notional.wadMul(rateVolatilityFactor);
        adjustedMargin += volatilityAdjustment.wadMul(maturityDays * 1e18 / 365);

        return adjustedMargin > baseMargin ? adjustedMargin : baseMargin;
    }

    /// @notice Calculate required maintenance margin for a position
    /// @param positionId The position ID
    /// @return requiredMargin Minimum maintenance margin
    function calculateMaintenanceMargin(
        uint256 positionId
    ) external view returns (uint256 requiredMargin) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) revert PositionNotActive(positionId);

        // Base maintenance margin
        uint256 baseMargin = uint256(pos.notional).wadMul(maintenanceMarginRatio);

        // Adjust for unrealized PnL (negative PnL requires more margin)
        int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
        if (unrealizedPnL < 0) {
            // Add absolute value of negative PnL to required margin
            baseMargin += uint256(-unrealizedPnL);
        }

        return baseMargin;
    }

    /// @notice Calculate health factor for a position
    /// @param positionId The position ID
    /// @return healthFactor Position health (>1 = healthy, <1 = liquidatable)
    function getHealthFactor(
        uint256 positionId
    ) external view returns (uint256 healthFactor) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return 0;

        // Calculate effective margin (current margin + unrealized PnL)
        int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
        int256 effectiveMargin = int256(uint256(pos.margin)) + pos.accumulatedPnL + unrealizedPnL;

        if (effectiveMargin <= 0) return 0;

        // Calculate required maintenance margin
        uint256 requiredMargin = uint256(pos.notional).wadMul(maintenanceMarginRatio);

        // Health factor = effective margin / required margin
        return uint256(effectiveMargin).wadDiv(requiredMargin);
    }

    /// @notice Check if a position is liquidatable
    /// @param positionId The position ID
    /// @return isLiquidatable True if position can be liquidated
    function isLiquidatable(
        uint256 positionId
    ) external view returns (bool) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return false;

        // Calculate health factor
        int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
        int256 effectiveMargin = int256(uint256(pos.margin)) + pos.accumulatedPnL + unrealizedPnL;

        if (effectiveMargin <= 0) return true;

        uint256 requiredMargin = uint256(pos.notional).wadMul(maintenanceMarginRatio);
        uint256 healthFactor = uint256(effectiveMargin).wadDiv(requiredMargin);

        return healthFactor < liquidationThreshold;
    }

    /// @notice Get margin utilization for a position
    /// @param positionId The position ID
    /// @return utilization Margin utilization ratio (higher = riskier)
    function getMarginUtilization(
        uint256 positionId
    ) external view returns (uint256 utilization) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return 0;

        uint256 requiredMargin = uint256(pos.notional).wadMul(maintenanceMarginRatio);
        int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
        int256 effectiveMargin = int256(uint256(pos.margin)) + pos.accumulatedPnL + unrealizedPnL;

        if (effectiveMargin <= 0) return type(uint256).max;

        // Utilization = required / effective (inverted health factor)
        return requiredMargin.wadDiv(uint256(effectiveMargin));
    }

    /// @notice Calculate maximum notional for given margin
    /// @param margin Available margin
    /// @param maturityDays Time to maturity
    /// @return maxNotional Maximum notional that can be opened
    function calculateMaxNotional(
        uint256 margin,
        uint256 maturityDays
    ) external view returns (uint256 maxNotional) {
        // maxNotional = margin / initialMarginRatio (simplified)
        uint256 baseMax = margin.wadDiv(initialMarginRatio);

        // Apply leverage cap
        uint256 leverageCap = margin.wadMul(maxLeverage);

        // Apply maturity adjustment (lower notional for longer maturities)
        uint256 maturityFactor = _getMaturityFactor(maturityDays);
        uint256 adjustedMax = baseMax.wadDiv(maturityFactor);

        // Return the minimum of the two
        return adjustedMax < leverageCap ? adjustedMax : leverageCap;
    }

    /// @notice Get current leverage of a position
    /// @param positionId The position ID
    /// @return leverage Current leverage ratio
    function getPositionLeverage(
        uint256 positionId
    ) external view returns (uint256 leverage) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return 0;

        int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
        int256 effectiveMargin = int256(uint256(pos.margin)) + pos.accumulatedPnL + unrealizedPnL;

        if (effectiveMargin <= 0) return type(uint256).max;

        return uint256(pos.notional).wadDiv(uint256(effectiveMargin));
    }

    /// @notice Get distance to liquidation
    /// @param positionId The position ID
    /// @return marginBuffer How much margin can be lost before liquidation
    function getMarginBuffer(
        uint256 positionId
    ) external view returns (int256 marginBuffer) {
        PositionManager.Position memory pos = positionManager.getPosition(positionId);
        if (!pos.isActive) return 0;

        int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
        int256 effectiveMargin = int256(uint256(pos.margin)) + pos.accumulatedPnL + unrealizedPnL;

        uint256 requiredMargin = uint256(pos.notional).wadMul(maintenanceMarginRatio);

        // Buffer = effective margin - required margin (at liquidation threshold)
        return effectiveMargin - int256(requiredMargin.wadMul(liquidationThreshold));
    }

    /// @notice Batch check health factors for multiple positions
    /// @param positionIds Array of position IDs
    /// @return healthFactors Array of health factors
    function batchGetHealthFactors(
        uint256[] calldata positionIds
    ) external view returns (uint256[] memory healthFactors) {
        healthFactors = new uint256[](positionIds.length);

        for (uint256 i = 0; i < positionIds.length; i++) {
            PositionManager.Position memory pos = positionManager.getPosition(positionIds[i]);
            if (!pos.isActive) {
                healthFactors[i] = 0;
                continue;
            }

            int256 unrealizedPnL = _calculateUnrealizedPnL(pos);
            int256 effectiveMargin = int256(uint256(pos.margin)) + pos.accumulatedPnL + unrealizedPnL;

            if (effectiveMargin <= 0) {
                healthFactors[i] = 0;
            } else {
                uint256 requiredMargin = uint256(pos.notional).wadMul(maintenanceMarginRatio);
                healthFactors[i] = uint256(effectiveMargin).wadDiv(requiredMargin);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update margin ratios
    /// @dev Phase 1 Security: Uses constants for bounds validation
    /// @param _initialRatio New initial margin ratio (5%-50%)
    /// @param _maintenanceRatio New maintenance margin ratio (2.5%-initial)
    /// @param _liquidationThreshold New liquidation threshold
    function setMarginParameters(
        uint256 _initialRatio,
        uint256 _maintenanceRatio,
        uint256 _liquidationThreshold
    ) external onlyOwner {
        // Phase 1 Security: Stricter bounds using constants
        if (_initialRatio < MIN_INITIAL_MARGIN_RATIO || _initialRatio > MAX_INITIAL_MARGIN_RATIO) {
            revert InvalidRatio();
        }
        if (_maintenanceRatio < MIN_MAINTENANCE_MARGIN_RATIO || _maintenanceRatio >= _initialRatio) {
            revert InvalidRatio();
        }
        if (_liquidationThreshold == 0 || _liquidationThreshold > 2e18) revert InvalidThreshold();

        initialMarginRatio = _initialRatio;
        maintenanceMarginRatio = _maintenanceRatio;
        liquidationThreshold = _liquidationThreshold;

        emit MarginParametersUpdated(_initialRatio, _maintenanceRatio, _liquidationThreshold);
    }

    /// @notice Update maximum leverage
    /// @dev Phase 1 Security: Capped at ABSOLUTE_MAX_LEVERAGE
    /// @param _maxLeverage New maximum leverage (max 20x)
    function setMaxLeverage(uint256 _maxLeverage) external onlyOwner {
        if (_maxLeverage == 0 || _maxLeverage > ABSOLUTE_MAX_LEVERAGE) revert InvalidLeverage();
        maxLeverage = _maxLeverage;
        emit MaxLeverageUpdated(_maxLeverage);
    }

    /// @notice Update rate volatility factor
    /// @dev Phase 1 Security: Capped at MAX_VOLATILITY_FACTOR
    /// @param _factor New volatility factor (max 25%)
    function setRateVolatilityFactor(uint256 _factor) external onlyOwner {
        if (_factor > MAX_VOLATILITY_FACTOR) revert InvalidRatio();
        rateVolatilityFactor = _factor;
        emit RateVolatilityFactorUpdated(_factor);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate unrealized PnL for a position
    /// @param pos The position data
    /// @return pnl Unrealized profit/loss
    function _calculateUnrealizedPnL(
        PositionManager.Position memory pos
    ) internal view returns (int256 pnl) {
        // Get current floating rate
        uint256 currentRate = rateOracle.getCurrentRate();

        // Calculate time since last settlement
        uint256 endTime = block.timestamp > pos.maturity ? pos.maturity : block.timestamp;
        uint256 periodSeconds = endTime > pos.lastSettlement ? endTime - pos.lastSettlement : 0;

        if (periodSeconds == 0) return 0;

        // Calculate interest for the period
        uint256 fixedInterest = uint256(pos.notional)
            .wadMul(pos.fixedRate)
            .wadMul(periodSeconds * 1e18 / SECONDS_PER_YEAR);

        uint256 floatingInterest = uint256(pos.notional)
            .wadMul(currentRate)
            .wadMul(periodSeconds * 1e18 / SECONDS_PER_YEAR);

        // Calculate net based on position direction
        if (pos.isPayingFixed) {
            pnl = int256(floatingInterest) - int256(fixedInterest);
        } else {
            pnl = int256(fixedInterest) - int256(floatingInterest);
        }
    }

    /// @notice Get maturity adjustment factor
    /// @param maturityDays Days to maturity
    /// @return factor Adjustment factor (>1 for longer maturities)
    function _getMaturityFactor(uint256 maturityDays) internal pure returns (uint256 factor) {
        // Linear scaling: 30d = 1.0x, 365d = 1.5x
        if (maturityDays <= 30) return 1e18;
        if (maturityDays >= 365) return 1.5e18;

        // Linear interpolation
        uint256 extraDays = maturityDays - 30;
        uint256 maxExtraDays = 365 - 30; // 335 days
        uint256 extraFactor = (0.5e18 * extraDays) / maxExtraDays;

        return 1e18 + extraFactor;
    }
}
