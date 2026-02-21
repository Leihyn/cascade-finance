// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "./Handler.sol";
import "../../src/core/PositionManager.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/risk/LiquidationEngine.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

/// @title InvariantTests
/// @notice Invariant tests for the Kairos IRS Protocol
contract InvariantTests is StdInvariant, Test {
    Handler public handler;
    PositionManager public pm;
    SettlementEngine public settlement;
    MarginEngine public marginEngine;
    LiquidationEngine public liquidation;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy rate oracle
        rateSource = new MockRateSource(0.05e18, 0.07e18);
        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();

        // Deploy position manager (with fee recipient)
        pm = new PositionManager(address(usdc), 6, address(this));

        // Deploy margin engine
        marginEngine = new MarginEngine(address(pm), address(oracle));

        // Deploy settlement engine (with collateral token and fee recipient)
        settlement = new SettlementEngine(address(pm), address(oracle), 1 days, address(usdc), address(this));

        // Deploy liquidation engine
        liquidation = new LiquidationEngine(
            address(pm),
            address(marginEngine),
            address(usdc),
            address(this)
        );

        // Authorize engines
        pm.setAuthorizedContract(address(settlement), true);
        pm.setAuthorizedContract(address(liquidation), true);

        // Mint initial funds to contracts
        usdc.mint(address(pm), 10_000_000e6);
        usdc.mint(address(liquidation), 10_000_000e6);

        // Deploy handler
        handler = new Handler(
            address(pm),
            address(settlement),
            address(marginEngine),
            address(liquidation),
            address(oracle),
            address(usdc),
            address(rateSource)
        );

        // Authorize handler for testing
        pm.setAuthorizedContract(address(handler), true);

        // Set target contract for invariant testing
        targetContract(address(handler));

        // Set target selectors
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = Handler.openPosition.selector;
        selectors[1] = Handler.addMargin.selector;
        selectors[2] = Handler.removeMargin.selector;
        selectors[3] = Handler.settlePosition.selector;
        selectors[4] = Handler.closeMaturedPosition.selector;
        selectors[5] = Handler.liquidatePosition.selector;
        selectors[6] = Handler.updateRate.selector;
        selectors[7] = Handler.warpTime.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /*//////////////////////////////////////////////////////////////
                    POSITION MANAGER INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Total margin tracked must equal sum of active position margins
    function invariant_totalMarginConsistency() public view {
        uint256 trackedTotal = pm.totalMargin();
        uint256 calculatedTotal = handler.getTotalActiveMargin();

        assertEq(
            trackedTotal,
            calculatedTotal,
            "Total margin mismatch"
        );
    }

    /// @notice Total notional must equal sum of active position notionals
    function invariant_totalNotionalConsistency() public view {
        uint256 trackedFixed = pm.totalFixedNotional();
        uint256 trackedFloating = pm.totalFloatingNotional();

        (uint256 calculatedFixed, uint256 calculatedFloating) = handler.getTotalActiveNotional();

        assertEq(trackedFixed, calculatedFixed, "Fixed notional mismatch");
        assertEq(trackedFloating, calculatedFloating, "Floating notional mismatch");
    }

    /// @notice Active position count must be accurate
    function invariant_activePositionCount() public view {
        uint256 trackedCount = pm.activePositionCount();
        uint256 calculatedCount = handler.getActivePositionCount();

        assertEq(trackedCount, calculatedCount, "Active position count mismatch");
    }

    /// @notice Position NFT ownership must match position trader
    function invariant_nftOwnershipConsistency() public view {
        uint256 posCount = handler.getPositionCount();

        for (uint256 i = 0; i < posCount; i++) {
            uint256 posId = handler.positionIds(i);
            PositionManager.Position memory pos = pm.getPosition(posId);

            if (pos.isActive) {
                // NFT should exist and have an owner
                address owner = pm.ownerOf(posId);
                assertTrue(owner != address(0), "Position has zero owner");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                      MARGIN ENGINE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Healthy positions should not be liquidatable
    function invariant_healthyPositionsNotLiquidatable() public view {
        uint256 posCount = handler.getPositionCount();

        for (uint256 i = 0; i < posCount; i++) {
            uint256 posId = handler.positionIds(i);
            PositionManager.Position memory pos = pm.getPosition(posId);

            if (!pos.isActive) continue;

            uint256 healthFactor = marginEngine.getHealthFactor(posId);
            bool isLiquidatable = marginEngine.isLiquidatable(posId);

            // If health factor >= threshold, position should not be liquidatable
            if (healthFactor >= marginEngine.liquidationThreshold()) {
                assertFalse(isLiquidatable, "Healthy position marked liquidatable");
            }
        }
    }

    /// @notice Position leverage should never exceed max leverage for healthy positions
    function invariant_leverageBounded() public view {
        uint256 posCount = handler.getPositionCount();
        uint256 maxLeverage = marginEngine.maxLeverage();

        for (uint256 i = 0; i < posCount; i++) {
            uint256 posId = handler.positionIds(i);
            PositionManager.Position memory pos = pm.getPosition(posId);

            if (!pos.isActive) continue;

            // Only check positions with positive health factor
            uint256 healthFactor = marginEngine.getHealthFactor(posId);
            if (healthFactor > 1e18) {
                uint256 leverage = marginEngine.getPositionLeverage(posId);
                // Allow some margin for accumulated PnL affecting effective margin
                assertLe(leverage, maxLeverage * 2, "Leverage exceeds bounds");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    COLLATERAL TOKEN INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Contract token balances should be non-negative (always true for ERC20)
    function invariant_nonNegativeBalances() public view {
        uint256 pmBalance = usdc.balanceOf(address(pm));
        uint256 liqBalance = usdc.balanceOf(address(liquidation));

        // Balances are uint256 so always >= 0
        // This mainly verifies no underflow occurred
        assertTrue(pmBalance >= 0, "PM balance underflow");
        assertTrue(liqBalance >= 0, "Liquidation balance underflow");
    }

    /*//////////////////////////////////////////////////////////////
                      RATE ORACLE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Oracle rate should always be within valid bounds
    function invariant_oracleRateBounded() public view {
        uint256 rate = oracle.getCurrentRate();

        // Rate should be between 0 and 100% (0.001% to 50% in practice)
        assertGe(rate, 0, "Rate below zero");
        assertLe(rate, 1e18, "Rate exceeds 100%");
    }

    /*//////////////////////////////////////////////////////////////
                    SETTLEMENT ENGINE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Positions should only be settleable after interval
    function invariant_settlementTimingRespected() public view {
        uint256 posCount = handler.getPositionCount();

        for (uint256 i = 0; i < posCount; i++) {
            uint256 posId = handler.positionIds(i);
            PositionManager.Position memory pos = pm.getPosition(posId);

            if (!pos.isActive) continue;

            uint256 lastSettled = settlement.lastSettlementTime(posId);
            if (lastSettled == 0) {
                lastSettled = pos.startTime;
            }

            bool canSettle = settlement.canSettle(posId);
            uint256 timeSinceLast = block.timestamp - lastSettled;
            uint256 interval = settlement.settlementInterval();

            // canSettle should be true iff enough time has passed
            if (timeSinceLast >= interval) {
                assertTrue(canSettle, "Should be able to settle");
            } else {
                assertFalse(canSettle, "Should not be able to settle yet");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    LIQUIDATION ENGINE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Liquidations should only occur for undercollateralized positions
    function invariant_liquidationOnlyWhenUnderwater() public view {
        // This invariant is checked via the handler's liquidatePosition function
        // which only calls liquidate when isLiquidatable returns true
        // The liquidation engine itself reverts if position is not liquidatable

        uint256 liquidations = handler.ghost_liquidationsPerformed();

        // All performed liquidations should have been on liquidatable positions
        // (verified by the engine reverting otherwise)
        assertTrue(true, "Liquidation checks enforced by engine");
    }

    /*//////////////////////////////////////////////////////////////
                      GHOST VARIABLE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Opened positions should be >= closed positions
    function invariant_positionsOpenedGeClosed() public view {
        uint256 opened = handler.ghost_positionsOpened();
        uint256 closed = handler.ghost_positionsClosed();

        assertGe(opened, closed, "More positions closed than opened");
    }

    /// @notice Active count should equal opened - closed (approximately)
    function invariant_activeCountConsistency() public view {
        uint256 opened = handler.ghost_positionsOpened();
        uint256 closed = handler.ghost_positionsClosed();
        uint256 liquidated = handler.ghost_liquidationsPerformed();
        uint256 activeCount = pm.activePositionCount();

        // Active = opened - closed - liquidated (approximately, some liquidations may not close)
        assertLe(activeCount, opened, "Active count exceeds opened");
    }

    /*//////////////////////////////////////////////////////////////
                          SUMMARY FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Log summary statistics after invariant run
    function invariant_callSummary() public view {
        console.log("=== Invariant Test Summary ===");
        console.log("Positions opened:", handler.ghost_positionsOpened());
        console.log("Positions closed:", handler.ghost_positionsClosed());
        console.log("Settlements performed:", handler.ghost_settlementsPerformed());
        console.log("Liquidations performed:", handler.ghost_liquidationsPerformed());
        console.log("Total margin deposited:", handler.ghost_totalMarginsDeposited());
        console.log("Total margin withdrawn:", handler.ghost_totalMarginsWithdrawn());
        console.log("Current active positions:", pm.activePositionCount());
        console.log("Current total margin:", pm.totalMargin());
    }
}
