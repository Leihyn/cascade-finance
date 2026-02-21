# Kairos IRS Protocol - Full Security Audit Report

**Protocol:** Kairos Interest Rate Swap Protocol
**Auditor:** Manual Security Analysis
**Date:** December 31, 2025
**Commit:** Pre-fix state
**Methods:** Static Analysis, Code Review, Proof of Concept Testing

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Scope](#scope)
3. [Findings Overview](#findings-overview)
4. [Critical Findings](#critical-findings)
5. [High Severity Findings](#high-severity-findings)
6. [Proof of Concept Tests](#proof-of-concept-tests)
7. [Recommendations](#recommendations)

---

## Executive Summary

The Kairos IRS Protocol is an on-chain interest rate swap platform allowing users to trade fixed vs floating rate exposure. The protocol consists of:

- **PositionManager**: ERC721-based position NFTs with margin management
- **OrderBook**: Peer-to-peer order matching for IRS positions
- **SettlementEngine**: Periodic settlement of positions based on oracle rates
- **LiquidationEngine**: Liquidation of undercollateralized positions
- **MarginEngine**: Health factor and margin requirement calculations
- **RateOracle**: Aggregated floating rate from multiple DeFi protocols
- **Comet**: Compound V3-style lending pool

### Critical Assessment

**The protocol is non-functional in its current state.** Four critical bugs prevent core operations:

| Component | Status | Impact |
|-----------|--------|--------|
| Order Matching | **BROKEN** | 100% revert rate |
| Liquidations | **BROKEN** | 100% revert rate |
| Lending Collateral | **EXPLOITABLE** | Complete fund drain possible |
| Keeper Incentives | **FAKE** | No actual payments |

This appears to be early-stage/hackathon code requiring significant remediation before any deployment.

---

## Scope

### Contracts Audited

| Contract | SLOC | Complexity |
|----------|------|------------|
| `src/core/PositionManager.sol` | 827 | High |
| `src/core/OrderBook.sol` | 515 | Medium |
| `src/core/SettlementEngine.sol` | 541 | High |
| `src/risk/LiquidationEngine.sol` | 457 | Medium |
| `src/risk/MarginEngine.sol` | 371 | Medium |
| `src/pricing/RateOracle.sol` | 311 | Medium |
| `src/lending/Comet.sol` | 437 | High |
| `src/lending/CometStorage.sol` | 106 | Low |
| `src/libraries/FixedPointMath.sol` | 187 | Low |

### Out of Scope
- Frontend code
- Deployment scripts
- Test files
- External dependencies (OpenZeppelin)

---

## Findings Overview

| ID | Title | Severity | Status |
|----|-------|----------|--------|
| C-01 | OrderBook calls wrong PositionManager function | Critical | Confirmed |
| C-02 | LiquidationEngine pays 103% of seized margin | Critical | Confirmed |
| C-03 | Comet lending has no price oracle | Critical | Confirmed |
| C-04 | Keeper rewards tracked but never paid | Critical | Confirmed |
| H-01 | Unsafe int256 to int128 cast in updatePositionPnL | High | Confirmed |
| H-02 | settleInternal uses tx.origin for reward attribution | High | Confirmed |

---

## Critical Findings

### [C-01] OrderBook Calls Wrong PositionManager Function

**Severity:** Critical
**Likelihood:** Certain
**Impact:** Complete DOS of order matching functionality

#### Description

The `OrderBook._createPositionFor()` function is designed to create positions on behalf of matched traders. It correctly transfers margin to the PositionManager first, then attempts to call `openPosition()`. However, `openPosition()` expects to pull tokens via `safeTransferFrom`, creating a double-transfer scenario that always reverts.

#### Vulnerable Code

```solidity
// OrderBook.sol:491-512
function _createPositionFor(
    address trader,
    bool isPayingFixed,
    uint128 notional,
    uint128 fixedRate,
    uint40 maturityDays,
    uint128 margin
) internal returns (uint256 positionId) {
    // Step 1: Push margin TO PositionManager
    collateralToken.safeTransfer(address(positionManager), margin);

    // Step 2: Call openPosition - THIS WILL REVERT
    positionId = positionManager.openPosition(  // <-- WRONG FUNCTION
        isPayingFixed,
        notional,
        fixedRate,
        maturityDays,
        margin
    );

    // Step 3: Never reached
    positionManager.transferFrom(address(this), trader, positionId);
}
```

```solidity
// PositionManager.sol:256
function openPosition(...) external nonReentrant returns (uint256 positionId) {
    // ...
    // Tries to PULL tokens that OrderBook already sent!
    collateralToken.safeTransferFrom(msg.sender, address(this), margin + feeAmount);
    // ...
}
```

#### Root Cause Analysis

1. `OrderBook` pushes `margin` to `PositionManager` via `safeTransfer()` (line 493)
2. `OrderBook` calls `openPosition()` (line 503)
3. `openPosition()` calls `safeTransferFrom(OrderBook, PositionManager, margin + fee)`
4. **REVERT**: OrderBook has no tokens left AND never approved PositionManager

#### The Irony

The correct function `openPositionFor()` already exists at PositionManager line 305-375, specifically designed for this use case:

```solidity
/// @notice Open a position on behalf of another address (for OrderBook)
/// @dev Only authorized contracts can call this. Margin must be pre-transferred.
function openPositionFor(
    address trader,
    bool isPayingFixed,
    uint128 notional,
    uint128 fixedRate,
    uint256 maturityDays,
    uint128 margin
) external nonReentrant onlyAuthorized returns (uint256 positionId) {
    // Note: Margin should already be transferred by the authorized contract
    // No safeTransferFrom here!
}
```

#### Impact

- **100% of order matching fails**
- OrderBook is completely non-functional
- Users cannot create matched IRS positions
- Funds deposited for orders are stuck until cancelled

#### Proof of Concept

See `test/audit/C01_OrderBookWrongFunction.t.sol`

#### Remediation

```diff
- positionId = positionManager.openPosition(
+ positionId = positionManager.openPositionFor(
+     trader,
      isPayingFixed,
      notional,
      fixedRate,
      maturityDays,
      margin
  );
- positionManager.transferFrom(address(this), trader, positionId);
```

---

### [C-02] LiquidationEngine Pays 103% of Seized Margin

**Severity:** Critical
**Likelihood:** Certain
**Impact:** All liquidations revert, protocol insolvency during volatility

#### Description

The liquidation reward calculation uses a multiplier that results in paying the liquidator MORE than the amount seized from the position. Since the contract only receives `marginSeized` but attempts to transfer `marginSeized * 1.03`, every liquidation reverts with insufficient balance.

#### Vulnerable Code

```solidity
// LiquidationEngine.sol:120-124 (defaults)
liquidationBonus = 0.05e18;      // 5%
protocolFee = 0.02e18;           // 2%
maxLiquidationRatio = 0.50e18;   // 50%
```

```solidity
// LiquidationEngine.sol:436-456
function _calculateLiquidationAmounts(
    PositionManager.Position memory pos
) internal view returns (uint256 marginSeized, uint256 liquidatorReward) {
    marginSeized = uint256(pos.margin).wadMul(maxLiquidationRatio);
    // marginSeized = 100 * 0.5 = 50

    if (marginSeized > pos.margin) {
        marginSeized = pos.margin;
    }

    // BROKEN MATH:
    uint256 rewardMultiplier = 1e18 + liquidationBonus - protocolFee;
    // rewardMultiplier = 1e18 + 0.05e18 - 0.02e18 = 1.03e18

    liquidatorReward = marginSeized.wadMul(rewardMultiplier);
    // liquidatorReward = 50 * 1.03 = 51.5  <-- MORE THAN SEIZED!

    // This cap checks against pos.margin (100), not marginSeized (50)
    if (liquidatorReward > pos.margin) {
        liquidatorReward = pos.margin;
    }
    // 51.5 < 100, so no cap applied
}
```

```solidity
// LiquidationEngine.sol:156-160
// Contract receives 50 tokens
positionManager.reduceMargin(positionId, uint128(marginSeized), address(this));

// Contract tries to send 51.5 tokens - REVERT!
collateralToken.safeTransfer(msg.sender, liquidatorReward);
```

#### Numeric Proof

For position with `margin = 100`:

| Variable | Calculation | Value |
|----------|-------------|-------|
| marginSeized | 100 × 0.50 | 50 |
| rewardMultiplier | 1 + 0.05 - 0.02 | 1.03 |
| liquidatorReward | 50 × 1.03 | 51.5 |
| Contract receives | reduceMargin() | 50 |
| Contract sends | safeTransfer() | 51.5 |
| **Shortfall** | | **1.5** |

#### Impact

- **100% of liquidations revert**
- Underwater positions cannot be liquidated
- Bad debt accumulates during market volatility
- Protocol becomes insolvent

#### Proof of Concept

See `test/audit/C02_LiquidationMath.t.sol`

#### Remediation

```solidity
// Option 1: Bonus comes FROM protocol fee, not ON TOP of seized
uint256 protocolFeeAmount = marginSeized.wadMul(protocolFee);
uint256 effectiveBonus = liquidationBonus > protocolFee ? protocolFee : liquidationBonus;
uint256 bonusAmount = marginSeized.wadMul(effectiveBonus);
liquidatorReward = marginSeized - protocolFeeAmount + bonusAmount;

// Option 2: Simple cap
if (liquidatorReward > marginSeized) {
    liquidatorReward = marginSeized;
}
```

---

### [C-03] Comet Lending Has No Price Oracle

**Severity:** Critical
**Likelihood:** Certain
**Impact:** Complete protocol drain, trivial exploitation

#### Description

The Comet lending pool calculates collateral value by simply summing raw token amounts without any price conversion. This means 1 unit of any collateral token equals 1 unit of the base token, regardless of actual market prices.

#### Vulnerable Code

```solidity
// Comet.sol:392-403
function _getCollateralValue(address account) internal view returns (uint256) {
    uint256 totalValue = 0;
    for (uint8 i = 0; i < _assetConfigs.length; i++) {
        AssetConfig memory config = _assetConfigs[i];
        uint128 collateral = _userCollateral[account][config.asset];
        if (collateral > 0) {
            // Simplified: assume 1:1 with base token (should use oracle in production)
            totalValue += collateral;  // <-- NO PRICE CONVERSION!
        }
    }
    return totalValue;
}
```

The same bug exists in:
- `_getBorrowCollateralValue()` (line 405)
- `_getLiquidationCollateralValue()` (line 419)

#### Attack Scenario

**Setup:**
- Base token: USDC (6 decimals, $1 per token)
- Collateral: SHITCOIN (18 decimals, $0 value)
- Borrow collateral factor: 70%

**Attack:**
1. Attacker creates worthless ERC20 token
2. Attacker deposits 1,000,000e18 SHITCOIN as collateral
3. System calculates: `collateralValue = 1,000,000e18`
4. System allows borrow: `1,000,000e18 * 0.7 = 700,000e18` base tokens
5. If base token is USDC with 6 decimals, math breaks further
6. Attacker drains all USDC from protocol

**Even with same decimals:**
1. Attacker deposits 1000 worthless tokens (worth $0)
2. System thinks value = 1000 USDC
3. Attacker borrows 700 USDC
4. Protocol loses $700 per attack

#### Impact

- **Complete protocol insolvency**
- Any user can drain all funds
- No collateral actually backs any loans
- Immediate critical vulnerability upon deployment

#### Proof of Concept

See `test/audit/C03_CometNoOracle.t.sol`

#### Remediation

```solidity
// Add oracle interface
import "./interfaces/IPriceOracle.sol";

// Add state variable
IPriceOracle public priceOracle;

// Fix collateral calculation
function _getCollateralValue(address account) internal view returns (uint256) {
    uint256 totalValue = 0;
    for (uint8 i = 0; i < _assetConfigs.length; i++) {
        AssetConfig memory config = _assetConfigs[i];
        uint128 collateral = _userCollateral[account][config.asset];
        if (collateral > 0) {
            uint256 price = priceOracle.getPrice(config.asset);
            uint256 value = (uint256(collateral) * price) / 1e18;
            totalValue += value;
        }
    }
    return totalValue;
}
```

---

### [C-04] Keeper Rewards Tracked But Never Paid

**Severity:** Critical
**Likelihood:** Certain
**Impact:** No keeper incentives, settlements may not occur

#### Description

The SettlementEngine tracks keeper rewards in `totalKeeperRewardsPaid` and emits `KeeperRewardPaid` events, but never actually transfers any tokens to keepers. The `withdrawFees()` function sends ALL collected fees to the protocol, ignoring the keeper reward accounting entirely.

#### Vulnerable Code

```solidity
// SettlementEngine.sol:177-183 - Tracking without payment
if (keeperRewardPercentage > 0) {
    uint256 keeperReward = feeAmount.wadMul(keeperRewardPercentage);
    totalKeeperRewardsPaid += keeperReward;  // Just tracking
    emit KeeperRewardPaid(msg.sender, positionId, keeperReward);  // Event emitted
    // NO ACTUAL TRANSFER TO KEEPER!
}
```

```solidity
// SettlementEngine.sol:445-457 - All fees go to protocol
function withdrawFees() external onlyOwner {
    uint256 settlementFees = totalSettlementFeesCollected;
    uint256 closeFees = totalCloseFeesCollected;
    uint256 totalFees = settlementFees + closeFees;
    // NOTE: totalKeeperRewardsPaid is COMPLETELY IGNORED

    if (totalFees == 0) revert NoFeesToWithdraw();

    totalSettlementFeesCollected = 0;
    totalCloseFeesCollected = 0;

    // ALL fees go to protocol, keepers get NOTHING
    collateralToken.safeTransfer(protocolFeeRecipient, totalFees);
}
```

#### Verification

```bash
$ grep -r "claimKeeperReward" src/
# No results - function doesn't exist
```

#### Impact

- **Keepers receive no compensation for settlements**
- Events suggest payments that never happen (misleading/fraud)
- Rational keepers won't participate
- Settlements may not occur, positions never close
- Protocol relies on altruistic actors

#### Proof of Concept

See `test/audit/C04_KeeperRewardsUnpaid.t.sol`

#### Remediation

```solidity
// Option A: Pay keeper immediately
if (keeperRewardPercentage > 0) {
    uint256 keeperReward = feeAmount.wadMul(keeperRewardPercentage);
    collateralToken.safeTransfer(msg.sender, keeperReward);
    totalSettlementFeesCollected -= keeperReward;
    emit KeeperRewardPaid(msg.sender, positionId, keeperReward);
}

// Option B: Add claim function
function claimKeeperReward(address keeper) external {
    uint256 reward = pendingKeeperRewards[keeper];
    pendingKeeperRewards[keeper] = 0;
    collateralToken.safeTransfer(keeper, reward);
}
```

---

## High Severity Findings

### [H-01] Unsafe int256 to int128 Cast

**Severity:** High
**Likelihood:** Low (requires extreme values)
**Impact:** Silent overflow corrupts position accounting

#### Description

```solidity
// PositionManager.sol:579
function updatePositionPnL(
    uint256 positionId,
    int256 pnlDelta  // 256-bit
) external onlyAuthorized positionActive(positionId) {
    Position storage pos = positions[positionId];
    pos.accumulatedPnL += int128(pnlDelta);  // UNSAFE: silent truncation
}
```

If `pnlDelta` exceeds int128 bounds (±1.7e38), the cast silently truncates, corrupting position accounting.

#### Remediation

```solidity
require(pnlDelta >= type(int128).min && pnlDelta <= type(int128).max, "overflow");
pos.accumulatedPnL += int128(pnlDelta);
```

---

### [H-02] settleInternal Uses tx.origin

**Severity:** High
**Likelihood:** Medium
**Impact:** Breaks smart contract wallet compatibility, phishing risk

#### Description

```solidity
// SettlementEngine.sol:258
emit KeeperRewardPaid(tx.origin, positionId, keeperReward);
```

Using `tx.origin` instead of `msg.sender`:
1. Breaks compatibility with smart contract wallets (Gnosis Safe, etc.)
2. In batch calls via `batchSettle()`, rewards are attributed to EOA, not calling contract
3. Inconsistent with `settle()` which correctly uses `msg.sender`

#### Remediation

Pass keeper address explicitly:
```solidity
function settleInternal(uint256 positionId, address keeper) external {
    // ...
    emit KeeperRewardPaid(keeper, positionId, keeperReward);
}
```

---

## Proof of Concept Tests

All PoC tests are located in `test/audit/` and can be run with:

```bash
forge test --match-path test/audit/*.sol -vvv
```

