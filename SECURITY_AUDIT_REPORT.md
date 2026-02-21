# Security Audit Report: Kairos IRS Protocol

**Auditor:** Manual Analysis (Sentinel had parsing issues)
**Date:** December 31, 2025
**Scope:** Core IRS contracts, Risk Management, Oracle, Lending

---

## Executive Summary

This audit identified **4 Critical** and **2 High** severity issues. Each finding below has been traced through code execution paths and verified.

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High | 2 |

---

## Critical Findings

### [C-01] OrderBook Calls Wrong Function - All Order Matching Broken

**Files:** `OrderBook.sol:492-509`, `PositionManager.sol:234-303`

**Root Cause:**
`_createPositionFor()` calls `openPosition()` instead of the existing `openPositionFor()`.

**Code Trace:**

```solidity
// OrderBook.sol:492-509
function _createPositionFor(...) internal returns (uint256 positionId) {
    // Step 1: Push margin TO PositionManager
    collateralToken.safeTransfer(address(positionManager), margin);

    // Step 2: Call openPosition (WRONG FUNCTION)
    positionId = positionManager.openPosition(...);
}
```

```solidity
// PositionManager.sol:256 - openPosition tries to PULL tokens
collateralToken.safeTransferFrom(msg.sender, address(this), margin + feeAmount);
```

**Execution Flow:**
1. OrderBook pushes `margin` to PositionManager via `safeTransfer` (line 493)
2. OrderBook calls `openPosition()` (line 503)
3. `openPosition()` calls `safeTransferFrom(OrderBook, PositionManager, margin + fee)`
4. **REVERT**: OrderBook doesn't have tokens (already sent) AND never approved PositionManager

**Impact:** 100% of order matching fails. The OrderBook is non-functional.

**The Fix Already Exists:**
```solidity
// PositionManager.sol:305-306 has openPositionFor():
/// @notice Open a position on behalf of another address (for OrderBook)
/// @dev Only authorized contracts can call this. Margin must be pre-transferred.
```

**Proof:** The comment on OrderBook line 499-500 even says:
> "Note: This is a simplified approach. In production, you'd want PositionManager to have an openPositionFor() function"

But `openPositionFor()` already exists at line 305.

---

### [C-02] LiquidationEngine Pays 103% of What It Receives - Guaranteed Revert

**Files:** `LiquidationEngine.sol:134-184, 436-456`

**Numeric Proof (Default Parameters):**
```
liquidationBonus = 0.05e18  (5%)
protocolFee = 0.02e18       (2%)
maxLiquidationRatio = 0.50e18 (50%)
```

For a position with `margin = 100`:

```solidity
// _calculateLiquidationAmounts() at line 440:
marginSeized = 100 * 0.50 = 50

// Line 449:
rewardMultiplier = 1e18 + 0.05e18 - 0.02e18 = 1.03e18

// Line 450:
liquidatorReward = 50 * 1.03 = 51.5
```

**Execution Flow in liquidate():**
```solidity
// Line 157: Contract RECEIVES 50 tokens
positionManager.reduceMargin(positionId, 50, address(this));

// Line 160: Contract tries to SEND 51.5 tokens
collateralToken.safeTransfer(msg.sender, 51.5);
// REVERT: "ERC20: transfer amount exceeds balance"
```

**Impact:** ALL liquidations revert. Underwater positions cannot be liquidated, leading to protocol insolvency during market volatility.

---

### [C-03] Comet Lending Has No Price Oracle - Broken Collateral Valuation

**File:** `Comet.sol:392-431`

**The Code:**
```solidity
function _getCollateralValue(address account) internal view returns (uint256) {
    uint256 totalValue = 0;
    for (uint8 i = 0; i < _assetConfigs.length; i++) {
        AssetConfig memory config = _assetConfigs[i];
        uint128 collateral = _userCollateral[account][config.asset];
        if (collateral > 0) {
            // Simplified: assume 1:1 with base token (should use oracle in production)
            totalValue += collateral;  // <-- NO PRICE CONVERSION
        }
    }
    return totalValue;
}
```

The same pattern repeats in:
- `_getBorrowCollateralValue()` (line 405)
- `_getLiquidationCollateralValue()` (line 419)

**Attack Scenario:**
1. Base token: USDC (6 decimals, $1 each)
2. Collateral: Worthless token (18 decimals, $0 value)
3. Attacker deposits 1000e18 worthless tokens
4. System calculates: `collateralValue = 1000e18`
5. With 70% collateral factor: borrowable = 700e18 USDC
6. Attacker borrows 700e18 USDC (impossible amount, or if decimals match, $700 worth)
7. Protocol is insolvent

**Impact:** Complete protocol insolvency. Anyone can drain all funds.

---

### [C-04] Keeper Rewards Are Tracked But Never Paid

**File:** `SettlementEngine.sol:69, 179, 257, 445-456`

**Tracking Code (line 179):**
```solidity
if (keeperRewardPercentage > 0) {
    uint256 keeperReward = feeAmount.wadMul(keeperRewardPercentage);
    totalKeeperRewardsPaid += keeperReward;  // Tracked
    emit KeeperRewardPaid(msg.sender, positionId, keeperReward);  // Event emitted
    // BUT NO ACTUAL TRANSFER TO KEEPER
}
```

**Withdrawal Code (line 445-456):**
```solidity
function withdrawFees() external onlyOwner {
    uint256 settlementFees = totalSettlementFeesCollected;
    uint256 closeFees = totalCloseFeesCollected;
    uint256 totalFees = settlementFees + closeFees;
    // NOTE: totalKeeperRewardsPaid is IGNORED

    collateralToken.safeTransfer(protocolFeeRecipient, totalFees);
    // ALL fees go to protocol, keepers get NOTHING
}
```

**Verified:** Searched entire codebase - no `claimKeeperReward()` function exists.

**Impact:**
- Keepers perform work expecting rewards that never materialize
- Events suggest payments that don't exist (accounting fraud / misleading)
- Settlement may not happen if keepers realize rewards are fake

---

## High Severity Findings

### [H-01] Unsafe int256 to int128 Cast in updatePositionPnL

**File:** `PositionManager.sol:579`

**The Code:**
```solidity
function updatePositionPnL(
    uint256 positionId,
    int256 pnlDelta  // 256-bit input
) external onlyAuthorized positionActive(positionId) {
    Position storage pos = positions[positionId];

    pos.accumulatedPnL += int128(pnlDelta);  // UNSAFE: truncates to 128-bit
}
```

**Contrast with Safe Implementation in Same Codebase:**
```solidity
// Comet.sol:433-435 does it correctly:
function _safe104(int256 x) internal pure returns (int104) {
    require(x >= type(int104).min && x <= type(int104).max, "int104 overflow");
    return int104(x);
}
```

**Impact:** If `pnlDelta` exceeds `int128` bounds (±1.7e38), the value silently wraps, corrupting position accounting. While extreme, this could occur with very high notional positions or in a targeted attack.

---

### [H-02] settleInternal Uses tx.origin for Reward Attribution

**File:** `SettlementEngine.sol:258`

**The Code:**
```solidity
// In settleInternal() - called via batchSettle():
emit KeeperRewardPaid(tx.origin, positionId, keeperReward);
```

**Contrast with settle():**
```solidity
// In settle() - direct call:
emit KeeperRewardPaid(msg.sender, positionId, keeperReward);  // Correct
```

**Impact:**
1. Breaks compatibility with smart contract wallets and multisigs
2. In a phishing attack, rewards are attributed to victim (`tx.origin`) not attacker's contract (`msg.sender`)
3. Inconsistent behavior between `settle()` and `batchSettle()` paths

Note: This is somewhat moot given C-04 (rewards aren't paid anyway), but represents a real code quality issue.

---

## What I Verified vs. What I Retracted

### Retracted from Previous Report:
- **[H-04] ownerOf reverts after closePosition** - WRONG. NFT is not burned, just marked inactive. `ownerOf()` still works.

### Verified Findings:
- All 4 Critical and 2 High findings above were traced through actual code execution paths
- Numeric values calculated with actual default parameters
- Cross-referenced function implementations

---

## Recommendations

### Immediate (Pre-Deploy):

1. **OrderBook**: Change line 503 from `openPosition()` to `openPositionFor()`

2. **LiquidationEngine**: Fix reward math - either:
   ```solidity
   // Option A: Liquidator gets seized minus protocol fee
   liquidatorReward = marginSeized - protocolFeeAmount;

   // Option B: Bonus comes FROM protocol fee, not on top of seized
   liquidatorReward = marginSeized.wadMul(1e18 - protocolFee + liquidationBonus);
   // Requires bonus < protocolFee
   ```

3. **Comet**: Integrate a price oracle (Chainlink, Uniswap TWAP, etc.)
   ```solidity
   uint256 price = oracle.getPrice(config.asset);
   uint256 value = (collateral * price) / PRICE_PRECISION;
   ```

4. **SettlementEngine**: Either implement actual keeper reward claims OR remove the misleading tracking:
   ```solidity
   // Option A: Pay keeper directly
   collateralToken.safeTransfer(msg.sender, keeperReward);

   // Option B: Remove fake tracking
   // Delete totalKeeperRewardsPaid and related events
   ```

5. **PositionManager**: Add bounds check:
   ```solidity
   require(pnlDelta >= type(int128).min && pnlDelta <= type(int128).max, "overflow");
   pos.accumulatedPnL += int128(pnlDelta);
   ```

---

## Conclusion

The protocol has 4 critical bugs that make core functionality non-operational:
- Order matching will revert (C-01)
- Liquidations will revert (C-02)
- Lending is exploitable (C-03)
- Keeper incentives are fake (C-04)

These are not edge cases - they affect 100% of the intended functionality. The codebase appears to be in early development/hackathon state and requires significant fixes before any deployment.

---

*This report contains only verified findings with traced execution paths. Each critical finding was confirmed through code analysis, not pattern matching.*
