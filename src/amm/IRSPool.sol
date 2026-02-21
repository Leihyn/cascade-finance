// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FixedPointMath} from "../libraries/FixedPointMath.sol";

/// @title IRSPool
/// @notice Automated Market Maker for Interest Rate Swaps
/// @dev Uses a specialized bonding curve for fixed-floating rate trading
contract IRSPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using FixedPointMath for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PoolState {
        uint256 fixedRateLiquidity;   // Liquidity backing fixed rate side
        uint256 floatingRateLiquidity; // Liquidity backing floating rate side
        uint256 totalLpShares;         // Total LP shares outstanding
        uint256 lastRate;              // Last traded rate
        uint256 lastUpdateTime;        // Last update timestamp
    }

    struct LPPosition {
        uint256 shares;
        uint256 depositTime;
        uint256 entryRate;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The collateral token (e.g., USDC)
    IERC20 public immutable collateralToken;

    /// @notice Token decimals
    uint8 public immutable decimals;

    /// @notice Pool state
    PoolState public pool;

    /// @notice LP positions
    mapping(address => LPPosition) public lpPositions;

    /// @notice Target rate set by oracle
    uint256 public targetRate;

    /// @notice Fee in basis points (100 = 1%)
    uint256 public fee = 30; // 0.3%

    /// @notice Protocol fee share in basis points
    uint256 public protocolFeeShare = 1000; // 10% of trading fees

    /// @notice Accumulated protocol fees
    uint256 public protocolFees;

    /// @notice Fee recipient
    address public feeRecipient;

    /// @notice Minimum liquidity to prevent manipulation
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /// @notice Curve parameter - controls rate sensitivity
    uint256 public curveK = 1e18; // Constant product style

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LiquidityAdded(address indexed provider, uint256 amount, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 amount, uint256 shares);
    event RateSwap(
        address indexed trader,
        bool isPayingFixed,
        uint256 notional,
        uint256 rate,
        uint256 fee
    );
    event TargetRateUpdated(uint256 oldRate, uint256 newRate);
    event PoolRebalanced(uint256 fixedLiquidity, uint256 floatingLiquidity);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _collateralToken,
        uint8 _decimals,
        address _feeRecipient,
        uint256 _initialRate
    ) Ownable(msg.sender) {
        collateralToken = IERC20(_collateralToken);
        decimals = _decimals;
        feeRecipient = _feeRecipient;
        targetRate = _initialRate;
        pool.lastRate = _initialRate;
        pool.lastUpdateTime = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                          LIQUIDITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add liquidity to the pool
    /// @param amount Amount of collateral to deposit
    /// @return shares LP shares received
    function addLiquidity(uint256 amount) external nonReentrant returns (uint256 shares) {
        require(amount > 0, "IRSPool: zero amount");

        // Transfer collateral
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate shares
        uint256 totalLiquidity = pool.fixedRateLiquidity + pool.floatingRateLiquidity;

        if (pool.totalLpShares == 0) {
            // First deposit
            shares = amount - MINIMUM_LIQUIDITY;
            pool.totalLpShares = MINIMUM_LIQUIDITY; // Lock minimum liquidity

            // Split evenly between fixed and floating
            pool.fixedRateLiquidity = amount / 2;
            pool.floatingRateLiquidity = amount - pool.fixedRateLiquidity;
        } else {
            shares = (amount * pool.totalLpShares) / totalLiquidity;

            // Add proportionally to both sides
            uint256 fixedShare = (amount * pool.fixedRateLiquidity) / totalLiquidity;
            pool.fixedRateLiquidity += fixedShare;
            pool.floatingRateLiquidity += amount - fixedShare;
        }

        pool.totalLpShares += shares;

        LPPosition storage position = lpPositions[msg.sender];
        position.shares += shares;
        position.depositTime = block.timestamp;
        position.entryRate = pool.lastRate;

        emit LiquidityAdded(msg.sender, amount, shares);
    }

    /// @notice Remove liquidity from the pool
    /// @param shares LP shares to burn
    /// @return amount Collateral returned
    function removeLiquidity(uint256 shares) external nonReentrant returns (uint256 amount) {
        LPPosition storage position = lpPositions[msg.sender];
        require(position.shares >= shares, "IRSPool: insufficient shares");

        uint256 totalLiquidity = pool.fixedRateLiquidity + pool.floatingRateLiquidity;
        amount = (shares * totalLiquidity) / pool.totalLpShares;

        // Update pool state
        uint256 fixedRemoved = (shares * pool.fixedRateLiquidity) / pool.totalLpShares;
        pool.fixedRateLiquidity -= fixedRemoved;
        pool.floatingRateLiquidity -= (amount - fixedRemoved);
        pool.totalLpShares -= shares;
        position.shares -= shares;

        // Transfer collateral back
        collateralToken.safeTransfer(msg.sender, amount);

        emit LiquidityRemoved(msg.sender, amount, shares);
    }

    /*//////////////////////////////////////////////////////////////
                           TRADING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get a quote for a rate swap
    /// @param isPayingFixed True if paying fixed rate
    /// @param notional The notional amount
    /// @return rate The quoted fixed rate
    /// @return feeAmount The fee in collateral
    function getQuote(bool isPayingFixed, uint256 notional)
        public
        view
        returns (uint256 rate, uint256 feeAmount)
    {
        // Calculate the rate based on pool imbalance
        // Using a simplified AMM formula: rate = baseRate * (1 + imbalance * sensitivity)

        uint256 totalLiquidity = pool.fixedRateLiquidity + pool.floatingRateLiquidity;
        require(totalLiquidity > 0, "IRSPool: no liquidity");

        // Calculate imbalance
        int256 imbalance;
        if (isPayingFixed) {
            // Paying fixed = receiving floating = more demand for fixed rate
            // This should push the fixed rate up
            imbalance = int256(pool.floatingRateLiquidity) - int256(pool.fixedRateLiquidity);
        } else {
            // Receiving fixed = paying floating = more demand for floating rate
            // This should push the fixed rate down
            imbalance = int256(pool.fixedRateLiquidity) - int256(pool.floatingRateLiquidity);
        }

        // Normalize imbalance and apply to target rate
        // imbalance ratio = imbalance / totalLiquidity
        // rate adjustment = targetRate * imbalance_ratio * sensitivity

        uint256 sensitivity = 1e17; // 10% max deviation from target
        int256 adjustment = (int256(targetRate) * imbalance * int256(sensitivity)) /
                           (int256(totalLiquidity) * 1e18);

        int256 signedRate = int256(targetRate) + adjustment;
        rate = signedRate > 0 ? uint256(signedRate) : 0;

        // Apply slippage based on size
        uint256 sizeImpact = (notional * 1e15) / totalLiquidity; // 0.1% per 1% of pool
        if (isPayingFixed) {
            rate = rate + (rate * sizeImpact / 1e18);
        } else {
            rate = rate > (rate * sizeImpact / 1e18) ? rate - (rate * sizeImpact / 1e18) : 0;
        }

        // Calculate fee
        feeAmount = (notional * fee) / 10000;
    }

    /// @notice Execute a rate swap
    /// @param isPayingFixed True if paying fixed rate
    /// @param notional The notional amount
    /// @param minRate Minimum acceptable rate (for receiving fixed)
    /// @param maxRate Maximum acceptable rate (for paying fixed)
    /// @return rate The executed fixed rate
    function swap(
        bool isPayingFixed,
        uint256 notional,
        uint256 minRate,
        uint256 maxRate
    ) external nonReentrant returns (uint256 rate) {
        uint256 feeAmount;
        (rate, feeAmount) = getQuote(isPayingFixed, notional);

        // Check slippage
        if (isPayingFixed) {
            require(rate <= maxRate, "IRSPool: rate too high");
        } else {
            require(rate >= minRate, "IRSPool: rate too low");
        }

        // Collect fee
        collateralToken.safeTransferFrom(msg.sender, address(this), feeAmount);

        // Split protocol fee
        uint256 protocolFeeAmount = (feeAmount * protocolFeeShare) / 10000;
        protocolFees += protocolFeeAmount;

        // Add remaining fee to liquidity
        uint256 lpFee = feeAmount - protocolFeeAmount;
        if (isPayingFixed) {
            pool.fixedRateLiquidity += lpFee / 2;
            pool.floatingRateLiquidity += lpFee - lpFee / 2;
        } else {
            pool.floatingRateLiquidity += lpFee / 2;
            pool.fixedRateLiquidity += lpFee - lpFee / 2;
        }

        // Update pool state based on trade direction
        // Trades shift liquidity between sides
        uint256 shift = notional / 100; // 1% of notional shifts liquidity
        if (isPayingFixed) {
            uint256 actualShift = shift > pool.floatingRateLiquidity / 10
                ? pool.floatingRateLiquidity / 10
                : shift;
            pool.fixedRateLiquidity += actualShift;
            pool.floatingRateLiquidity -= actualShift;
        } else {
            uint256 actualShift = shift > pool.fixedRateLiquidity / 10
                ? pool.fixedRateLiquidity / 10
                : shift;
            pool.floatingRateLiquidity += actualShift;
            pool.fixedRateLiquidity -= actualShift;
        }

        pool.lastRate = rate;
        pool.lastUpdateTime = block.timestamp;

        emit RateSwap(msg.sender, isPayingFixed, notional, rate, feeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get total pool liquidity
    function getTotalLiquidity() external view returns (uint256) {
        return pool.fixedRateLiquidity + pool.floatingRateLiquidity;
    }

    /// @notice Get the current implied rate
    function getCurrentRate() external view returns (uint256) {
        uint256 totalLiquidity = pool.fixedRateLiquidity + pool.floatingRateLiquidity;
        if (totalLiquidity == 0) return targetRate;

        int256 imbalance = int256(pool.floatingRateLiquidity) - int256(pool.fixedRateLiquidity);
        uint256 sensitivity = 1e17;
        int256 adjustment = (int256(targetRate) * imbalance * int256(sensitivity)) /
                           (int256(totalLiquidity) * 1e18);

        int256 currentRate = int256(targetRate) + adjustment;
        return currentRate > 0 ? uint256(currentRate) : 0;
    }

    /// @notice Get LP position details
    function getLpPosition(address provider)
        external
        view
        returns (uint256 shares, uint256 value, uint256 depositTime)
    {
        LPPosition storage position = lpPositions[provider];
        shares = position.shares;
        depositTime = position.depositTime;

        uint256 totalLiquidity = pool.fixedRateLiquidity + pool.floatingRateLiquidity;
        value = pool.totalLpShares > 0
            ? (shares * totalLiquidity) / pool.totalLpShares
            : 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the target rate (from oracle)
    function setTargetRate(uint256 newRate) external onlyOwner {
        emit TargetRateUpdated(targetRate, newRate);
        targetRate = newRate;
    }

    /// @notice Set fee parameters
    function setFees(uint256 _fee, uint256 _protocolFeeShare) external onlyOwner {
        require(_fee <= 1000, "IRSPool: fee too high"); // Max 10%
        require(_protocolFeeShare <= 5000, "IRSPool: protocol share too high"); // Max 50%
        fee = _fee;
        protocolFeeShare = _protocolFeeShare;
    }

    /// @notice Withdraw protocol fees
    function withdrawProtocolFees() external {
        uint256 amount = protocolFees;
        protocolFees = 0;
        collateralToken.safeTransfer(feeRecipient, amount);
    }

    /// @notice Set fee recipient
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    /// @notice Emergency rebalance (admin only)
    function rebalance(uint256 fixedRatio) external onlyOwner {
        require(fixedRatio <= 1e18, "IRSPool: invalid ratio");

        uint256 totalLiquidity = pool.fixedRateLiquidity + pool.floatingRateLiquidity;
        pool.fixedRateLiquidity = (totalLiquidity * fixedRatio) / 1e18;
        pool.floatingRateLiquidity = totalLiquidity - pool.fixedRateLiquidity;

        emit PoolRebalanced(pool.fixedRateLiquidity, pool.floatingRateLiquidity);
    }
}
