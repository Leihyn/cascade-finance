# BANK OF MANTLE - IMPLEMENTATION GUIDE
## Completing Missing Features & Fixing Weaknesses

**Last Updated:** January 10, 2026
**Priority:** Critical Path to Production
**Estimated Timeline:** 8-12 weeks

---

## TABLE OF CONTENTS

1. [Multi-Source Oracle Implementation](#1-multi-source-oracle-implementation)
2. [Multi-Collateral Support](#2-multi-collateral-support)
3. [Flash Loan Integration](#3-flash-loan-integration)
4. [Cross-Margining Engine](#4-cross-margining-engine)
5. [Partial Position Management](#5-partial-position-management)
6. [Interest Rate AMM Improvements](#6-interest-rate-amm-improvements)
7. [Liquidity Bootstrapping](#7-liquidity-bootstrapping)
8. [Advanced Trading Features](#8-advanced-trading-features)
9. [Testing & Deployment](#9-testing--deployment)

---

## 1. MULTI-SOURCE ORACLE IMPLEMENTATION

### Problem
**Current:** Single rate source (internal Comet only)
**Risk:** Oracle manipulation, single point of failure
**Solution:** Aggregate 3-5 independent rate sources using median

### Implementation Steps

#### Step 1.1: Connect Existing Adapters (Week 1)

You already have adapters for Aave and Compound. Just need to deploy and connect them:

```solidity
// script/ConnectOracles.s.sol
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/pricing/RateOracle.sol";
import "../src/adapters/AaveV3RateAdapter.sol";
import "../src/adapters/CompoundV3RateAdapter.sol";

contract ConnectOracles is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get existing RateOracle
        RateOracle oracle = RateOracle(0x8D1d3d7c373E84509DC86d1000cBDDE92123b23b);

        // Deploy Aave V3 adapter (Base Mainnet)
        AaveV3RateAdapter aaveAdapter = new AaveV3RateAdapter(
            0xA238Dd80C259a72e81d7e4664a9801593F98d1c5, // Aave V3 Pool (Base)
            0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb  // USDC reserve (Base)
        );

        // Deploy Compound V3 adapter (Base Mainnet)
        CompoundV3RateAdapter compoundAdapter = new CompoundV3RateAdapter(
            0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf  // Compound V3 USDC (Base)
        );

        // Add sources to oracle
        oracle.addSource(address(aaveAdapter));
        oracle.addSource(address(compoundAdapter));

        // Update oracle settings
        oracle.setMinSources(3); // Require at least 3 sources
        oracle.setMaxStaleness(3600); // 1 hour staleness tolerance

        vm.stopBroadcast();
    }
}
```

**Deploy:**
```bash
forge script script/ConnectOracles.s.sol:ConnectOracles \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify
```

#### Step 1.2: Add MakerDAO DSR Adapter (Week 1)

```solidity
// src/adapters/MakerDSRAdapter.sol
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";

interface IPot {
    function dsr() external view returns (uint256);
    function chi() external view returns (uint256);
}

contract MakerDSRAdapter is IRateSource {
    IPot public immutable pot;

    constructor(address _pot) {
        pot = IPot(_pot);
    }

    function getSupplyRate() external view override returns (uint256) {
        // DSR is in RAY (1e27), convert to WAD (1e18)
        uint256 dsr = pot.dsr();

        // Annualize: (dsr - RAY) * secondsPerYear
        // Convert RAY to WAD: divide by 1e9
        uint256 rayPerSecond = dsr - 1e27;
        uint256 wadPerYear = (rayPerSecond * 31536000) / 1e9;

        return wadPerYear;
    }

    function getBorrowRate() external view override returns (uint256) {
        return 0; // DSR is supply-only
    }

    function getLastUpdateTimestamp() external view override returns (uint256) {
        return block.timestamp; // Pot always fresh
    }
}
```

#### Step 1.3: Add Chainlink Rate Feed Fallback (Week 1)

```solidity
// src/adapters/ChainlinkRateAdapter.sol
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkRateAdapter is IRateSource {
    AggregatorV3Interface public immutable priceFeed;
    uint256 public immutable maxStaleness;

    constructor(address _priceFeed, uint256 _maxStaleness) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        maxStaleness = _maxStaleness;
    }

    function getSupplyRate() external view override returns (uint256) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(answeredInRound >= roundId, "Stale price");
        require(block.timestamp - updatedAt < maxStaleness, "Price too old");
        require(answer > 0, "Invalid price");

        // Chainlink reports rates in 8 decimals, convert to WAD (18 decimals)
        return uint256(answer) * 1e10;
    }

    function getBorrowRate() external view override returns (uint256) {
        return getSupplyRate(); // Same rate for fallback
    }

    function getLastUpdateTimestamp() external view override returns (uint256) {
        (, , , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return updatedAt;
    }
}
```

#### Step 1.4: Enhanced Oracle Validation (Week 2)

Update `RateOracle.sol` to handle source failures gracefully:

```solidity
// Add to src/pricing/RateOracle.sol

function getCurrentRateWithFallback() external view returns (uint256) {
    uint256[] memory validRates = new uint256[](sources.length);
    uint256 validCount = 0;

    // Collect rates from all sources
    for (uint256 i = 0; i < sources.length; i++) {
        try sources[i].getSupplyRate() returns (uint256 rate) {
            // Validate rate is not stale
            if (block.timestamp - sources[i].getLastUpdateTimestamp() < maxStaleness) {
                // Validate rate is within bounds
                if (rate >= MIN_RATE && rate <= MAX_RATE) {
                    validRates[validCount] = rate;
                    validCount++;
                }
            }
        } catch {
            // Source failed, skip it
            emit SourceFailed(address(sources[i]));
        }
    }

    require(validCount >= minSources, "Insufficient valid sources");

    // Get median of valid rates
    return _medianOfArray(validRates, validCount);
}

function _medianOfArray(uint256[] memory arr, uint256 length) private pure returns (uint256) {
    // Create new array with only valid entries
    uint256[] memory validArr = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
        validArr[i] = arr[i];
    }

    // Sort
    for (uint256 i = 0; i < length; i++) {
        for (uint256 j = i + 1; j < length; j++) {
            if (validArr[i] > validArr[j]) {
                uint256 temp = validArr[i];
                validArr[i] = validArr[j];
                validArr[j] = temp;
            }
        }
    }

    // Return median
    if (length % 2 == 0) {
        return (validArr[length / 2 - 1] + validArr[length / 2]) / 2;
    } else {
        return validArr[length / 2];
    }
}
```

#### Step 1.5: Deploy Multi-Source Setup (Week 2)

**Final Oracle Configuration:**
```
Source 1: Internal Comet (existing)
Source 2: Aave V3 USDC
Source 3: Compound V3 USDC
Source 4: MakerDAO DSR
Source 5: Chainlink Rate Feed (fallback)

Min Sources: 3 (out of 5 must be valid)
Aggregation: Median (manipulation resistant)
Staleness: 1 hour max
Circuit Breaker: 200% max change (was 500%)
```

**Testing:**
```bash
# Deploy all adapters
forge script script/DeployOracles.s.sol --broadcast

# Test with one source down
forge test --match-test testOracleWithFailedSource -vvv

# Test with majority sources down (should revert)
forge test --match-test testOracleInsufficientSources -vvv

# Test median calculation
forge test --match-test testMedianAggregation -vvv
```

**Result:** ✅ **Multi-source oracle with fault tolerance**

---

## 2. MULTI-COLLATERAL SUPPORT

### Problem
**Current:** USDC only
**Limitation:** Users can't use ETH, WBTC, or other assets
**Solution:** Support multiple collateral types with Chainlink pricing

### Implementation Steps

#### Step 2.1: Update PositionManager for Multi-Collateral (Week 3)

```solidity
// Add to src/core/PositionManager.sol

struct CollateralConfig {
    address token;
    address priceFeed; // Chainlink aggregator
    uint256 collateralFactor; // e.g., 80% for ETH
    uint256 liquidationThreshold; // e.g., 85% for ETH
    bool enabled;
}

mapping(address => CollateralConfig) public collateralConfigs;
mapping(uint256 => address) public positionCollateral; // positionId => collateral token

event CollateralAdded(address indexed token, uint256 collateralFactor);
event CollateralRemoved(address indexed token);

function addCollateral(
    address token,
    address priceFeed,
    uint256 collateralFactor,
    uint256 liquidationThreshold
) external onlyOwner {
    require(collateralFactor < 1e18, "Invalid factor");
    require(liquidationThreshold > collateralFactor, "Threshold too low");

    collateralConfigs[token] = CollateralConfig({
        token: token,
        priceFeed: priceFeed,
        collateralFactor: collateralFactor,
        liquidationThreshold: liquidationThreshold,
        enabled: true
    });

    emit CollateralAdded(token, collateralFactor);
}

function openPositionWithCollateral(
    address collateralToken,
    uint256 collateralAmount,
    uint256 notional,
    uint256 fixedRate,
    uint256 maturity,
    PaySide paySide
) external nonReentrant returns (uint256) {
    require(collateralConfigs[collateralToken].enabled, "Collateral not supported");

    // Get USD value of collateral
    uint256 collateralValueUSD = _getCollateralValue(collateralToken, collateralAmount);

    // Check margin requirements (adjusted by collateral factor)
    uint256 requiredMarginUSD = _calculateRequiredMargin(notional, maturity);
    uint256 adjustedCollateralValue = collateralValueUSD *
        collateralConfigs[collateralToken].collateralFactor / 1e18;

    require(adjustedCollateralValue >= requiredMarginUSD, "Insufficient collateral");

    // Transfer collateral
    IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

    // Mint position
    uint256 positionId = _nextPositionId++;
    positionCollateral[positionId] = collateralToken;

    // ... rest of position creation

    return positionId;
}

function _getCollateralValue(address token, uint256 amount) internal view returns (uint256) {
    CollateralConfig memory config = collateralConfigs[token];

    // Get price from Chainlink
    AggregatorV3Interface priceFeed = AggregatorV3Interface(config.priceFeed);
    (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();

    require(block.timestamp - updatedAt < 3600, "Stale price");
    require(price > 0, "Invalid price");

    // Convert to USD (Chainlink prices are 8 decimals)
    uint256 priceUSD = uint256(price); // e.g., 2000_00000000 for $2000 ETH

    // Calculate value (adjust for token decimals)
    uint256 tokenDecimals = IERC20Metadata(token).decimals();
    uint256 valueUSD = (amount * priceUSD) / (10 ** tokenDecimals);

    return valueUSD; // Return in 8 decimals (Chainlink standard)
}
```

#### Step 2.2: Supported Collateral Assets (Week 3)

```solidity
// script/AddCollateralTypes.s.sol

contract AddCollateralTypes is Script {
    function run() external {
        vm.startBroadcast();

        PositionManager positionManager = PositionManager(0x...);

        // USDC (stablecoin - highest collateral factor)
        positionManager.addCollateral(
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC (Base)
            0x7e860098F58bBFC8648a4311b374B1D669a2bc6B, // USDC/USD feed
            95e16, // 95% collateral factor
            98e16  // 98% liquidation threshold
        );

        // WETH (volatile - moderate factor)
        positionManager.addCollateral(
            0x4200000000000000000000000000000000000006, // WETH (Base)
            0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70, // ETH/USD feed
            80e16, // 80% collateral factor
            85e16  // 85% liquidation threshold
        );

        // cbBTC (volatile - moderate factor)
        positionManager.addCollateral(
            0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, // cbBTC (Base)
            0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F, // BTC/USD feed
            75e16, // 75% collateral factor
            80e16  // 80% liquidation threshold
        );

        vm.stopBroadcast();
    }
}
```

#### Step 2.3: Update Liquidation for Multi-Collateral (Week 4)

```solidity
// Add to src/risk/LiquidationEngine.sol

function liquidateWithCollateralSwap(uint256 positionId) external nonReentrant {
    // Get position collateral type
    address collateralToken = positionManager.positionCollateral(positionId);

    // Calculate liquidation amounts
    (uint256 seizedCollateral, uint256 liquidationBonus) =
        _calculateLiquidationAmounts(positionId);

    // If collateral is not USDC, swap it first
    if (collateralToken != USDC) {
        uint256 usdcReceived = _swapCollateralToUSDC(
            collateralToken,
            seizedCollateral
        );

        // Pay liquidator in USDC
        IERC20(USDC).safeTransfer(msg.sender, usdcReceived);
    } else {
        // Direct transfer if USDC
        IERC20(USDC).safeTransfer(msg.sender, seizedCollateral);
    }

    // Close position
    positionManager.closePosition(positionId);

    emit Liquidated(positionId, msg.sender, seizedCollateral);
}

function _swapCollateralToUSDC(
    address fromToken,
    uint256 amount
) internal returns (uint256) {
    // Use integrated DEX for atomic swap
    address[] memory path = new address[](2);
    path[0] = fromToken;
    path[1] = USDC;

    // Approve router
    IERC20(fromToken).approve(address(swapRouter), amount);

    // Swap with 1% slippage tolerance
    uint256[] memory amounts = swapRouter.swapExactTokensForTokens(
        amount,
        amount * 99 / 100, // Min 99% of oracle price
        path,
        address(this),
        block.timestamp
    );

    return amounts[1]; // USDC received
}
```

**Testing:**
```bash
# Test ETH collateral
forge test --match-test testOpenPositionWithETH -vvv

# Test liquidation with ETH collateral
forge test --match-test testLiquidateETHPosition -vvv

# Test price impact on different collateral
forge test --match-test testCollateralPriceChange -vvv
```

**Result:** ✅ **Support for USDC, WETH, cbBTC collateral**

---

## 3. FLASH LOAN INTEGRATION

### Problem
**Current:** No flash loan support
**Use Case:** Arbitrage, liquidations, collateral swaps
**Solution:** Add EIP-3156 compliant flash loans to Comet

### Implementation Steps

#### Step 3.1: Add Flash Loan to Comet (Week 4)

```solidity
// Add to src/lending/Comet.sol

import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Comet is CometStorage, IERC3156FlashLender {
    uint256 public constant FLASH_LOAN_FEE = 9; // 0.09% (9 bps)
    bytes32 public constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    function maxFlashLoan(address token) external view override returns (uint256) {
        if (token != address(baseToken)) return 0;

        // Max is total supply minus borrowed
        uint256 available = baseToken.balanceOf(address(this));
        return available;
    }

    function flashFee(address token, uint256 amount) public view override returns (uint256) {
        require(token == address(baseToken), "Unsupported token");
        return (amount * FLASH_LOAN_FEE) / 10000;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant returns (bool) {
        require(token == address(baseToken), "Unsupported token");

        uint256 fee = flashFee(token, amount);
        uint256 balanceBefore = baseToken.balanceOf(address(this));

        // Transfer tokens to receiver
        baseToken.safeTransfer(address(receiver), amount);

        // Callback to receiver
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "Callback failed"
        );

        // Expect repayment + fee
        uint256 balanceAfter = baseToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");

        // Fee goes to reserves
        totalReserves += fee;

        emit FlashLoan(address(receiver), token, amount, fee);

        return true;
    }

    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
}
```

#### Step 3.2: Flash Loan Arbitrage Example (Week 4)

```solidity
// examples/FlashLoanArbitrage.sol

contract FlashLoanArbitrage is IERC3156FlashBorrower {
    Comet public immutable comet;
    SwapRouter public immutable router;

    constructor(address _comet, address _router) {
        comet = Comet(_comet);
        router = SwapRouter(_router);
    }

    function executeArbitrage(
        uint256 borrowAmount,
        address[] calldata path
    ) external {
        // Request flash loan
        comet.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(comet.baseToken()),
            borrowAmount,
            abi.encode(path)
        );
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(comet), "Untrusted lender");
        require(initiator == address(this), "Untrusted initiator");

        // Decode arbitrage path
        address[] memory path = abi.decode(data, (address[]));

        // Execute arbitrage swaps
        IERC20(token).approve(address(router), amount);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amount,
            amount + fee, // Must profit at least the fee
            path,
            address(this),
            block.timestamp
        );

        // Approve repayment
        IERC20(token).approve(address(comet), amount + fee);

        // Profit = amounts[amounts.length - 1] - (amount + fee)
        uint256 profit = amounts[amounts.length - 1] - (amount + fee);
        require(profit > 0, "Unprofitable");

        return CALLBACK_SUCCESS;
    }
}
```

#### Step 3.3: Flash Loan Liquidation Bot (Week 5)

```solidity
// examples/FlashLiquidator.sol

contract FlashLiquidator is IERC3156FlashBorrower {
    Comet public immutable comet;
    LiquidationEngine public immutable liquidationEngine;
    SwapRouter public immutable router;

    function liquidateWithFlashLoan(uint256 positionId) external {
        // Calculate required USDC for liquidation
        uint256 requiredUSDC = liquidationEngine.previewLiquidation(positionId);

        // Flash loan the required amount
        comet.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(comet.baseToken()),
            requiredUSDC,
            abi.encode(positionId)
        );
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(comet), "Untrusted lender");

        uint256 positionId = abi.decode(data, (uint256));

        // Execute liquidation
        IERC20(token).approve(address(liquidationEngine), amount);
        liquidationEngine.liquidate(positionId);

        // Position collateral + bonus now in this contract
        // Should be more than amount + fee

        // Repay flash loan
        IERC20(token).approve(address(comet), amount + fee);

        return CALLBACK_SUCCESS;
    }
}
```

**Testing:**
```bash
# Test basic flash loan
forge test --match-test testFlashLoan -vvv

# Test arbitrage
forge test --match-test testFlashLoanArbitrage -vvv

# Test liquidation with flash loan
forge test --match-test testFlashLiquidation -vvv
```

**Result:** ✅ **EIP-3156 flash loans enabled**

---

## 4. CROSS-MARGINING ENGINE

### Problem
**Current:** Each position isolated
**Inefficiency:** User with offsetting positions pays 2x margin
**Solution:** Portfolio-level margining

### Implementation Steps

#### Step 4.1: Create Cross-Margin Engine (Week 5-6)

```solidity
// src/risk/CrossMarginEngine.sol
pragma solidity ^0.8.24;

import "./MarginEngine.sol";
import "../core/PositionManager.sol";

contract CrossMarginEngine {
    PositionManager public immutable positionManager;
    MarginEngine public immutable marginEngine;

    struct Portfolio {
        uint256[] positionIds;
        int256 netExposure; // Net notional (positive = pay fixed bias)
        uint256 totalMargin;
        uint256 requiredMargin;
        uint256 healthFactor;
    }

    mapping(address => uint256[]) public userPositions;

    constructor(address _positionManager, address _marginEngine) {
        positionManager = PositionManager(_positionManager);
        marginEngine = MarginEngine(_marginEngine);
    }

    function getPortfolio(address user) external view returns (Portfolio memory) {
        uint256[] memory positions = userPositions[user];

        int256 netExposure;
        uint256 totalMargin;

        for (uint256 i = 0; i < positions.length; i++) {
            Position memory pos = positionManager.positions(positions[i]);

            // Calculate net exposure
            if (pos.paySide == PaySide.PAY_FIXED) {
                netExposure += int256(pos.notional);
            } else {
                netExposure -= int256(pos.notional);
            }

            totalMargin += pos.margin;
        }

        // Calculate portfolio margin (reduced for offsetting positions)
        uint256 requiredMargin = _calculatePortfolioMargin(
            positions,
            netExposure
        );

        uint256 healthFactor = totalMargin * 1e18 / requiredMargin;

        return Portfolio({
            positionIds: positions,
            netExposure: netExposure,
            totalMargin: totalMargin,
            requiredMargin: requiredMargin,
            healthFactor: healthFactor
        });
    }

    function _calculatePortfolioMargin(
        uint256[] memory positions,
        int256 netExposure
    ) internal view returns (uint256) {
        // Base case: sum of individual margins
        uint256 grossMargin;
        for (uint256 i = 0; i < positions.length; i++) {
            Position memory pos = positionManager.positions(positions[i]);
            grossMargin += marginEngine.calculateInitialMargin(
                pos.notional,
                pos.maturity
            );
        }

        // Offset reduction: reduce margin for netting
        uint256 netNotional = uint256(netExposure > 0 ? netExposure : -netExposure);

        // If positions offset, reduce margin by 30%
        if (positions.length > 1) {
            uint256 totalNotional;
            for (uint256 i = 0; i < positions.length; i++) {
                totalNotional += positionManager.positions(positions[i]).notional;
            }

            // Offset benefit = (total - net) / total
            uint256 offsetRatio = ((totalNotional - netNotional) * 1e18) / totalNotional;
            uint256 marginReduction = (grossMargin * offsetRatio * 30) / 100e18;

            return grossMargin - marginReduction;
        }

        return grossMargin;
    }

    function isPortfolioLiquidatable(address user) external view returns (bool) {
        Portfolio memory portfolio = this.getPortfolio(user);
        return portfolio.healthFactor < 1e18;
    }

    function registerPosition(address user, uint256 positionId) external {
        require(msg.sender == address(positionManager), "Only PositionManager");
        userPositions[user].push(positionId);
    }
}
```

#### Step 4.2: Integration Example (Week 6)

**Scenario:**
```
User has:
- Position A: $10,000 notional, Pay Fixed 5%
- Position B: $10,000 notional, Receive Fixed 5%

Without Cross-Margin:
- Required Margin A: $1,000 (10%)
- Required Margin B: $1,000 (10%)
- Total Required: $2,000

With Cross-Margin:
- Net Exposure: $0 (perfectly hedged)
- Required Margin: $700 (30% reduction)
- Saved: $1,300
```

**Testing:**
```solidity
function testCrossMarginBenefit() public {
    // Open offsetting positions
    uint256 pos1 = positionManager.openPosition({
        notional: 10_000e6,
        fixedRate: 5e16,
        maturity: block.timestamp + 30 days,
        paySide: PaySide.PAY_FIXED
    });

    uint256 pos2 = positionManager.openPosition({
        notional: 10_000e6,
        fixedRate: 5e16,
        maturity: block.timestamp + 30 days,
        paySide: PaySide.PAY_FLOATING
    });

    Portfolio memory portfolio = crossMarginEngine.getPortfolio(user);

    // Net exposure should be near zero
    assertEq(portfolio.netExposure, 0);

    // Required margin should be less than 2x individual
    uint256 individualMargin = marginEngine.calculateInitialMargin(10_000e6, block.timestamp + 30 days);
    assert(portfolio.requiredMargin < individualMargin * 2);
}
```

**Result:** ✅ **30% margin reduction for offsetting positions**

---

## 5. PARTIAL POSITION MANAGEMENT

### Problem
**Current:** All-or-nothing (100% open/close)
**Need:** Scale in/out, take partial profits
**Solution:** Fractional position operations

### Implementation Steps

#### Step 5.1: Add Partial Close Function (Week 7)

```solidity
// Add to src/core/PositionManager.sol

function partialClosePosition(
    uint256 positionId,
    uint256 percentToClose // in basis points (e.g., 5000 = 50%)
) external nonReentrant returns (uint256 pnl) {
    require(ownerOf(positionId) == msg.sender, "Not owner");
    require(percentToClose > 0 && percentToClose < 10000, "Invalid percent");

    Position storage position = positions[positionId];
    require(position.status == PositionStatus.ACTIVE, "Not active");

    // Settle outstanding PnL first
    settlementEngine.settle(positionId);

    // Calculate partial amounts
    uint256 notionalToClose = (position.notional * percentToClose) / 10000;
    uint256 marginToReturn = (position.margin * percentToClose) / 10000;

    // Calculate PnL on closed portion
    int256 totalPnL = position.settledPnL;
    int256 partialPnL = (totalPnL * int256(percentToClose)) / 10000;

    // Update position
    position.notional -= notionalToClose;
    position.margin -= marginToReturn;
    position.settledPnL -= partialPnL;

    // Transfer margin + PnL to user
    uint256 amountToReturn = marginToReturn;
    if (partialPnL > 0) {
        amountToReturn += uint256(partialPnL);
    } else {
        amountToReturn -= uint256(-partialPnL);
    }

    collateralToken.safeTransfer(msg.sender, amountToReturn);

    emit PartialClose(positionId, percentToClose, amountToReturn);

    return amountToReturn;
}

function scalePosition(
    uint256 positionId,
    uint256 additionalNotional,
    uint256 additionalMargin
) external nonReentrant {
    require(ownerOf(positionId) == msg.sender, "Not owner");

    Position storage position = positions[positionId];
    require(position.status == PositionStatus.ACTIVE, "Not active");

    // Check margin requirements for new total notional
    uint256 newNotional = position.notional + additionalNotional;
    uint256 newMargin = position.margin + additionalMargin;

    uint256 requiredMargin = marginEngine.calculateInitialMargin(
        newNotional,
        position.maturity
    );

    require(newMargin >= requiredMargin, "Insufficient margin");

    // Transfer additional margin
    collateralToken.safeTransferFrom(msg.sender, address(this), additionalMargin);

    // Update position
    position.notional = newNotional;
    position.margin = newMargin;

    emit PositionScaled(positionId, additionalNotional, additionalMargin);
}

event PartialClose(uint256 indexed positionId, uint256 percentClosed, uint256 amountReturned);
event PositionScaled(uint256 indexed positionId, uint256 additionalNotional, uint256 additionalMargin);
```

#### Step 5.2: Frontend Integration (Week 7)

```typescript
// frontend/hooks/usePartialClose.ts

export function usePartialClose(positionId: bigint) {
  const { writeContract } = useWriteContract();

  const partialClose = async (percentToClose: number) => {
    // percentToClose: 0-100
    const basisPoints = percentToClose * 100; // Convert to bps

    await writeContract({
      address: contracts.positionManager,
      abi: PositionManagerABI,
      functionName: 'partialClosePosition',
      args: [positionId, BigInt(basisPoints)]
    });
  };

  const scalePosition = async (
    additionalNotional: bigint,
    additionalMargin: bigint
  ) => {
    await writeContract({
      address: contracts.positionManager,
      abi: PositionManagerABI,
      functionName: 'scalePosition',
      args: [positionId, additionalNotional, additionalMargin]
    });
  };

  return { partialClose, scalePosition };
}
```

**UI Component:**
```tsx
<div className="space-y-4">
  <h3>Partial Close</h3>
  <input
    type="range"
    min="0"
    max="100"
    value={percentToClose}
    onChange={(e) => setPercentToClose(e.target.value)}
  />
  <div>Close {percentToClose}% of position</div>
  <button onClick={() => partialClose(percentToClose)}>
    Close Partial Position
  </button>
</div>
```

**Testing:**
```bash
# Test 50% partial close
forge test --match-test testPartialClose50Percent -vvv

# Test scaling position up
forge test --match-test testScalePositionUp -vvv

# Test multiple partial closes
forge test --match-test testMultiplePartialCloses -vvv
```

**Result:** ✅ **Granular position management**

---

## 6. INTEREST RATE AMM IMPROVEMENTS

### Problem
**Current:** Basic bonding curve, untested liquidity
**Issues:** High slippage, no LP incentives
**Solution:** Improved curve + rewards

### Implementation Steps

#### Step 6.1: Curve Optimization (Week 8)

```solidity
// Update src/amm/IRSPool.sol

function getQuote(
    uint256 fixedRateIn,
    uint256 notionalOut,
    PaySide side
) public view returns (uint256 requiredMargin) {
    // Use constant sum + constant product hybrid
    // k = x + y (low volatility)
    // k = x * y (high volatility)

    uint256 payFixedLiquidity = totalPayFixedNotional;
    uint256 payFloatingLiquidity = totalPayFloatingNotional;

    // Calculate imbalance
    uint256 totalLiq = payFixedLiquidity + payFloatingLiquidity;
    uint256 imbalance = payFixedLiquidity > payFloatingLiquidity
        ? payFixedLiquidity - payFloatingLiquidity
        : payFloatingLiquidity - payFixedLiquidity;

    uint256 imbalanceRatio = (imbalance * 1e18) / totalLiq;

    // Low imbalance: use constant sum (low slippage)
    if (imbalanceRatio < 0.2e18) { // < 20% imbalance
        return _constantSumQuote(fixedRateIn, notionalOut, side);
    }
    // High imbalance: use constant product (high slippage to rebalance)
    else {
        return _constantProductQuote(fixedRateIn, notionalOut, side);
    }
}

function _constantSumQuote(
    uint256 fixedRateIn,
    uint256 notionalOut,
    PaySide side
) internal view returns (uint256) {
    // Price stays constant regardless of trade size
    uint256 targetRate = rateOracle.getCurrentRate();

    // Fee increases with trade size
    uint256 baseFee = 30; // 0.3%
    uint256 sizeFee = (notionalOut * 1e18) /
        (totalPayFixedNotional + totalPayFloatingNotional);
    uint256 totalFee = baseFee + (sizeFee / 100);

    return (notionalOut * (10000 + totalFee)) / 10000;
}

function _constantProductQuote(
    uint256 fixedRateIn,
    uint256 notionalOut,
    PaySide side
) internal view returns (uint256) {
    // x * y = k
    uint256 x = totalPayFixedNotional;
    uint256 y = totalPayFloatingNotional;
    uint256 k = x * y;

    if (side == PaySide.PAY_FIXED) {
        // Buying pay-fixed, x decreases
        uint256 newX = x - notionalOut;
        uint256 newY = k / newX;
        return newY - y; // Amount of pay-floating to add
    } else {
        // Buying pay-floating, y decreases
        uint256 newY = y - notionalOut;
        uint256 newX = k / newY;
        return newX - x; // Amount of pay-fixed to add
    }
}
```

#### Step 6.2: LP Rewards (Week 8)

```solidity
// Add to src/amm/IRSPool.sol

struct LPRewards {
    uint256 totalRewards;
    uint256 rewardPerShare;
    mapping(address => uint256) userRewardDebt;
}

LPRewards public rewards;

function claimRewards() external {
    uint256 pending = pendingRewards(msg.sender);
    require(pending > 0, "No rewards");

    rewards.userRewardDebt[msg.sender] =
        (balanceOf[msg.sender] * rewards.rewardPerShare) / 1e18;

    collateralToken.safeTransfer(msg.sender, pending);

    emit RewardsClaimed(msg.sender, pending);
}

function pendingRewards(address user) public view returns (uint256) {
    uint256 accRewards = (balanceOf[user] * rewards.rewardPerShare) / 1e18;
    return accRewards - rewards.userRewardDebt[user];
}

function distributeRewards(uint256 amount) external onlyOwner {
    require(totalSupply > 0, "No LPs");

    rewards.rewardPerShare += (amount * 1e18) / totalSupply;
    rewards.totalRewards += amount;

    collateralToken.safeTransferFrom(msg.sender, address(this), amount);

    emit RewardsDistributed(amount);
}
```

**Testing:**
```bash
# Test curve at different imbalances
forge test --match-test testAMMCurveImbalance -vvv

# Test LP rewards distribution
forge test --match-test testLPRewards -vvv

# Test slippage tolerance
forge test --match-test testAMMSlippage -vvv
```

**Result:** ✅ **Improved AMM with rewards**

---

## 7. LIQUIDITY BOOTSTRAPPING

### Problem
**Current:** Empty pools, no liquidity
**Solution:** Incentive program + market making

### Implementation Steps

#### Step 7.1: Liquidity Mining Program (Week 9)

```solidity
// src/incentives/LiquidityMining.sol
pragma solidity ^0.8.24;

contract LiquidityMining {
    struct Pool {
        address poolAddress;
        uint256 rewardsPerSecond;
        uint256 lastUpdateTime;
        uint256 accRewardsPerShare;
        uint256 totalStaked;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    IERC20 public rewardToken; // Could be protocol token or USDC
    uint256 public poolCount;

    function addPool(address _pool, uint256 _rewardsPerSecond) external onlyOwner {
        pools[poolCount] = Pool({
            poolAddress: _pool,
            rewardsPerSecond: _rewardsPerSecond,
            lastUpdateTime: block.timestamp,
            accRewardsPerShare: 0,
            totalStaked: 0
        });
        poolCount++;
    }

    function deposit(uint256 poolId, uint256 amount) external {
        Pool storage pool = pools[poolId];
        UserInfo storage user = userInfo[poolId][msg.sender];

        updatePool(poolId);

        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accRewardsPerShare) / 1e18 - user.rewardDebt;
            if (pending > 0) {
                rewardToken.safeTransfer(msg.sender, pending);
            }
        }

        IERC20(pool.poolAddress).safeTransferFrom(msg.sender, address(this), amount);
        user.amount += amount;
        pool.totalStaked += amount;
        user.rewardDebt = (user.amount * pool.accRewardsPerShare) / 1e18;

        emit Deposit(msg.sender, poolId, amount);
    }

    function updatePool(uint256 poolId) public {
        Pool storage pool = pools[poolId];
        if (block.timestamp <= pool.lastUpdateTime) return;

        if (pool.totalStaked == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
        uint256 rewards = timeElapsed * pool.rewardsPerSecond;
        pool.accRewardsPerShare += (rewards * 1e18) / pool.totalStaked;
        pool.lastUpdateTime = block.timestamp;
    }
}
```

#### Step 7.2: Initial Liquidity Campaign (Week 9)

**Campaign Structure:**
```
Duration: 12 weeks
Total Rewards: $100,000 USDC
Distribution:
- Week 1-4: $50/day per pool (bootstrap)
- Week 5-8: $30/day per pool (sustain)
- Week 9-12: $20/day per pool (taper)

Pools:
- Comet Lending Pool: 40%
- DEX USDC/WETH Pair: 30%
- IRS AMM Pool: 30%
```

**Deploy:**
```bash
forge script script/DeployLiquidityMining.s.sol \
  --broadcast \
  --verify
```

**Result:** ✅ **Liquidity mining active**

---

## 8. ADVANCED TRADING FEATURES

### Problem
**Current:** Basic market orders only
**Need:** Professional trading tools

### Implementation Steps

#### Step 8.1: Advanced Order Types (Week 10)

```solidity
// Update src/core/Automation.sol

enum OrderType {
    LIMIT,
    STOP_LOSS,
    TAKE_PROFIT,
    TRAILING_STOP,
    OCO // One-Cancels-Other
}

struct AdvancedOrder {
    OrderType orderType;
    uint256 triggerRate;
    uint256 trailingDistance; // For trailing stop
    uint256 linkedOrderId; // For OCO
    bool active;
}

mapping(uint256 => AdvancedOrder) public advancedOrders;

function createTrailingStop(
    uint256 positionId,
    uint256 trailingDistance // in bps
) external returns (uint256 orderId) {
    require(ownerOf(positionId) == msg.sender, "Not owner");

    orderId = nextOrderId++;
    advancedOrders[orderId] = AdvancedOrder({
        orderType: OrderType.TRAILING_STOP,
        triggerRate: 0, // Dynamic
        trailingDistance: trailingDistance,
        linkedOrderId: 0,
        active: true
    });

    emit TrailingStopCreated(orderId, positionId, trailingDistance);
}

function executeTrailingStop(uint256 orderId) external {
    AdvancedOrder storage order = advancedOrders[orderId];
    require(order.active, "Order not active");
    require(order.orderType == OrderType.TRAILING_STOP, "Not trailing stop");

    // Get current PnL
    Position memory position = positions[orderId];
    int256 currentPnL = position.settledPnL;

    // Calculate trigger based on highest PnL seen
    // (This requires tracking high-water mark)

    // Execute if PnL dropped by trailing distance
    if (_shouldExecuteTrailingStop(orderId)) {
        positionManager.closePosition(orderId);
        order.active = false;

        // Pay keeper
        _payKeeperReward(msg.sender);
    }
}

function createOCO(
    uint256 takeProfitRate,
    uint256 stopLossRate
) external returns (uint256 tpOrderId, uint256 slOrderId) {
    // Create take-profit order
    tpOrderId = nextOrderId++;
    advancedOrders[tpOrderId] = AdvancedOrder({
        orderType: OrderType.TAKE_PROFIT,
        triggerRate: takeProfitRate,
        trailingDistance: 0,
        linkedOrderId: 0, // Will set after SL created
        active: true
    });

    // Create stop-loss order
    slOrderId = nextOrderId++;
    advancedOrders[slOrderId] = AdvancedOrder({
        orderType: OrderType.STOP_LOSS,
        triggerRate: stopLossRate,
        trailingDistance: 0,
        linkedOrderId: tpOrderId,
        active: true
    });

    // Link orders
    advancedOrders[tpOrderId].linkedOrderId = slOrderId;

    emit OCOCreated(tpOrderId, slOrderId);
}

function executeOCO(uint256 orderId) external {
    AdvancedOrder storage order = advancedOrders[orderId];
    require(order.active, "Order not active");

    // Execute this order
    _executeOrder(orderId);

    // Cancel linked order
    uint256 linkedId = order.linkedOrderId;
    advancedOrders[linkedId].active = false;

    emit OCOExecuted(orderId, linkedId);
}
```

#### Step 8.2: Rate Alerts (Week 10)

```solidity
// src/notifications/RateAlerts.sol

contract RateAlerts {
    struct Alert {
        address user;
        uint256 targetRate;
        bool above; // true = alert when above, false = below
        bool triggered;
    }

    mapping(uint256 => Alert) public alerts;
    uint256 public alertCount;

    event AlertTriggered(uint256 indexed alertId, uint256 rate);

    function createAlert(uint256 targetRate, bool above) external returns (uint256) {
        uint256 alertId = alertCount++;
        alerts[alertId] = Alert({
            user: msg.sender,
            targetRate: targetRate,
            above: above,
            triggered: false
        });

        return alertId;
    }

    function checkAlerts() external {
        uint256 currentRate = rateOracle.getCurrentRate();

        for (uint256 i = 0; i < alertCount; i++) {
            Alert storage alert = alerts[i];
            if (alert.triggered) continue;

            bool shouldTrigger = alert.above
                ? currentRate >= alert.targetRate
                : currentRate <= alert.targetRate;

            if (shouldTrigger) {
                alert.triggered = true;
                emit AlertTriggered(i, currentRate);
                // Could integrate with Push Protocol or EPNS for notifications
            }
        }
    }
}
```

**Result:** ✅ **Professional trading features**

---

## 9. TESTING & DEPLOYMENT

### Comprehensive Test Suite (Week 11)

```bash
# Create test suite for all new features
mkdir test/enhancements

# Multi-oracle tests
forge test --match-path "test/enhancements/MultiOracle.t.sol" -vvv

# Multi-collateral tests
forge test --match-path "test/enhancements/MultiCollateral.t.sol" -vvv

# Flash loan tests
forge test --match-path "test/enhancements/FlashLoan.t.sol" -vvv

# Cross-margin tests
forge test --match-path "test/enhancements/CrossMargin.t.sol" -vvv

# Partial close tests
forge test --match-path "test/enhancements/PartialClose.t.sol" -vvv

# Run all tests
forge test --gas-report

# Run invariant tests (2 hours)
forge test --match-path "test/invariant/*" -vvv

# Generate coverage report
forge coverage --report lcov
```

### Mainnet Deployment Checklist (Week 12)

```markdown
PRE-DEPLOYMENT:
- [ ] All tests passing (100%)
- [ ] Gas optimization complete
- [ ] Audit completed (critical/high fixed)
- [ ] Bug bounty live
- [ ] Emergency procedures documented
- [ ] Multi-sig setup (3/5 owners)

DEPLOYMENT STEPS:
1. Deploy infrastructure
   - [ ] Multi-source oracle
   - [ ] Chainlink price feeds
   - [ ] Rate adapters (Aave, Compound, Maker)

2. Deploy core contracts
   - [ ] Comet lending pool
   - [ ] DEX factory + router
   - [ ] Position manager
   - [ ] Settlement engine
   - [ ] Margin engine
   - [ ] Liquidation engine

3. Configure parameters
   - [ ] Set collateral types (USDC, WETH, cbBTC)
   - [ ] Set margin requirements
   - [ ] Set fee recipients
   - [ ] Set oracle sources
   - [ ] Set circuit breakers

4. Initialize liquidity
   - [ ] Seed Comet pool ($100k USDC)
   - [ ] Seed DEX pairs ($50k per pair)
   - [ ] Deploy liquidity mining

5. Transfer ownership
   - [ ] Transfer to multi-sig
   - [ ] Verify all contracts
   - [ ] Publish documentation

POST-DEPLOYMENT:
- [ ] Monitor for 48 hours
- [ ] Check keeper operations
- [ ] Verify oracle updates
- [ ] Test emergency pause
```

---

## IMPLEMENTATION TIMELINE

### Week-by-Week Schedule

| Week | Tasks | Deliverable |
|------|-------|-------------|
| **1-2** | Multi-source oracle, adapters, testing | ✅ 5 oracle sources |
| **3-4** | Multi-collateral support, liquidation updates | ✅ USDC/WETH/cbBTC support |
| **4-5** | Flash loans, arbitrage examples | ✅ EIP-3156 implementation |
| **5-6** | Cross-margining engine, portfolio view | ✅ 30% margin savings |
| **7** | Partial closes, position scaling | ✅ Fractional operations |
| **8** | AMM improvements, LP rewards | ✅ Better pricing curve |
| **9** | Liquidity mining, incentives | ✅ $100k rewards program |
| **10** | Advanced orders (trailing stop, OCO) | ✅ Pro trading features |
| **11** | Comprehensive testing, coverage | ✅ 100% test pass rate |
| **12** | Mainnet deployment, launch | ✅ Live on Base mainnet |

### Resource Requirements

**Development:**
- 1 Senior Solidity Developer: $15k/month × 3 months = $45k
- 1 Frontend Developer: $10k/month × 3 months = $30k
- 1 QA Engineer: $8k/month × 2 months = $16k

**Infrastructure:**
- Audit (Trail of Bits): $75k
- Bug bounty fund: $25k
- Liquidity mining rewards: $100k
- Initial liquidity: $150k

**Total Budget:** ~$450k

---

## PRIORITY RANKING

### CRITICAL (Do First)
1. ✅ Multi-source oracle (Weeks 1-2) - **Eliminates biggest risk**
2. ✅ Comprehensive testing (Week 11) - **Safety first**
3. ✅ Formal audit (External) - **Required for mainnet**

### HIGH (Do Next)
4. ✅ Multi-collateral (Weeks 3-4) - **Major UX improvement**
5. ✅ Cross-margining (Weeks 5-6) - **Capital efficiency**
6. ✅ Liquidity mining (Week 9) - **Bootstrap liquidity**

### MEDIUM (Nice to Have)
7. ✅ Flash loans (Weeks 4-5) - **Advanced users**
8. ✅ Partial closes (Week 7) - **Better UX**
9. ✅ AMM improvements (Week 8) - **Better pricing**

### LOW (Future Enhancements)
10. ✅ Advanced orders (Week 10) - **Power users**
11. ⚠️ Mobile app (Future) - **Not critical**
12. ⚠️ Governance (Future) - **Post-launch**

---

## SUCCESS METRICS

### Phase 1 Completion (Week 6)
- ✅ Multi-source oracle live
- ✅ Multi-collateral working
- ✅ Cross-margin implemented
- ✅ Flash loans functional

### Phase 2 Completion (Week 12)
- ✅ All features deployed
- ✅ Audit completed
- ✅ Mainnet launch
- ✅ $1M+ TVL within 30 days

### Long-term (6 months)
- ✅ $10M+ TVL
- ✅ 1000+ active users
- ✅ $1M+ weekly volume
- ✅ Zero critical incidents

---

**END OF IMPLEMENTATION GUIDE**

This guide provides step-by-step instructions to complete all missing features. Start with the critical items (multi-oracle) and work through systematically.

**Next Steps:**
1. Review this guide with your team
2. Prioritize based on resources
3. Begin Week 1 implementation (multi-oracle)
4. Set up weekly progress reviews

Good luck building! 🚀
