// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/risk/LiquidationEngine.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

/// @title Handler
/// @notice Handler contract for invariant testing - defines protocol actions
contract Handler is Test {
    PositionManager public pm;
    SettlementEngine public settlement;
    MarginEngine public marginEngine;
    LiquidationEngine public liquidation;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    // Track state for invariant checks
    uint256[] public positionIds;
    address[] public traders;

    // Ghost variables for tracking
    uint256 public ghost_totalMarginsDeposited;
    uint256 public ghost_totalMarginsWithdrawn;
    uint256 public ghost_positionsOpened;
    uint256 public ghost_positionsClosed;
    uint256 public ghost_settlementsPerformed;
    uint256 public ghost_liquidationsPerformed;

    // Constants
    uint256 constant MIN_NOTIONAL = 1_000e6;
    uint256 constant MAX_NOTIONAL = 1_000_000e6;
    uint256 constant MIN_MARGIN = 100e6;
    uint256 constant MAX_MARGIN = 100_000e6;
    uint256[] validMaturities;

    constructor(
        address _pm,
        address _settlement,
        address _marginEngine,
        address _liquidation,
        address _oracle,
        address _usdc,
        address _rateSource
    ) {
        pm = PositionManager(_pm);
        settlement = SettlementEngine(_settlement);
        marginEngine = MarginEngine(_marginEngine);
        liquidation = LiquidationEngine(_liquidation);
        oracle = RateOracle(_oracle);
        usdc = MockERC20(_usdc);
        rateSource = MockRateSource(_rateSource);

        validMaturities.push(30);
        validMaturities.push(90);
        validMaturities.push(180);
        validMaturities.push(365);

        // Setup initial traders
        for (uint256 i = 1; i <= 5; i++) {
            address trader = address(uint160(i * 1000));
            traders.push(trader);
            usdc.mint(trader, 10_000_000e6);
            vm.prank(trader);
            usdc.approve(address(pm), type(uint256).max);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          POSITION ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Open a new position with random parameters
    function openPosition(
        uint256 traderSeed,
        uint256 notionalSeed,
        uint256 rateSeed,
        uint256 maturitySeed,
        uint256 marginSeed,
        bool isPayingFixed
    ) external {
        // Select random trader
        address trader = traders[traderSeed % traders.length];

        // Bound inputs
        uint128 notional = uint128(bound(notionalSeed, MIN_NOTIONAL, MAX_NOTIONAL));
        uint128 fixedRate = uint128(bound(rateSeed, 0.01e18, 0.30e18));
        uint256 maturityDays = validMaturities[maturitySeed % validMaturities.length];

        // Calculate minimum margin and add buffer
        uint256 minMargin = uint256(notional) * 10 / 100;
        uint128 margin = uint128(bound(marginSeed, minMargin, minMargin * 3));

        // Check trader has enough balance
        if (usdc.balanceOf(trader) < margin) return;

        vm.prank(trader);
        try pm.openPosition(isPayingFixed, notional, fixedRate, maturityDays, margin) returns (uint256 posId) {
            positionIds.push(posId);
            ghost_totalMarginsDeposited += margin;
            ghost_positionsOpened++;
        } catch {
            // Position opening failed, that's ok
        }
    }

    /// @notice Add margin to an existing position
    function addMargin(uint256 positionSeed, uint256 amountSeed) external {
        if (positionIds.length == 0) return;

        uint256 posId = positionIds[positionSeed % positionIds.length];
        PositionManager.Position memory pos = pm.getPosition(posId);
        if (!pos.isActive) return;

        uint128 amount = uint128(bound(amountSeed, MIN_MARGIN, MAX_MARGIN));

        // Get position owner
        address owner = pm.ownerOf(posId);
        if (usdc.balanceOf(owner) < amount) return;

        vm.prank(owner);
        try pm.addMargin(posId, amount) {
            ghost_totalMarginsDeposited += amount;
        } catch {
            // Failed to add margin
        }
    }

    /// @notice Remove margin from a position
    function removeMargin(uint256 positionSeed, uint256 amountSeed) external {
        if (positionIds.length == 0) return;

        uint256 posId = positionIds[positionSeed % positionIds.length];
        PositionManager.Position memory pos = pm.getPosition(posId);
        if (!pos.isActive) return;

        // Calculate max removable margin
        uint256 minMargin = uint256(pos.notional) * 5 / 100;
        if (pos.margin <= minMargin) return;

        uint128 maxRemovable = uint128(pos.margin - minMargin);
        uint128 amount = uint128(bound(amountSeed, 1, maxRemovable));

        address owner = pm.ownerOf(posId);

        vm.prank(owner);
        try pm.removeMargin(posId, amount) {
            ghost_totalMarginsWithdrawn += amount;
        } catch {
            // Failed to remove margin
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settle a position
    function settlePosition(uint256 positionSeed) external {
        if (positionIds.length == 0) return;

        uint256 posId = positionIds[positionSeed % positionIds.length];
        PositionManager.Position memory pos = pm.getPosition(posId);
        if (!pos.isActive) return;

        // Check if can settle
        if (!settlement.canSettle(posId)) return;

        try settlement.settle(posId) {
            ghost_settlementsPerformed++;
        } catch {
            // Settlement failed
        }
    }

    /// @notice Close a matured position
    function closeMaturedPosition(uint256 positionSeed) external {
        if (positionIds.length == 0) return;

        uint256 posId = positionIds[positionSeed % positionIds.length];
        PositionManager.Position memory pos = pm.getPosition(posId);
        if (!pos.isActive) return;

        // Check if matured
        if (block.timestamp < pos.maturity) return;

        try settlement.closeMaturedPosition(posId) {
            ghost_positionsClosed++;
        } catch {
            // Close failed
        }
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDATION ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Liquidate a position if possible
    function liquidatePosition(uint256 positionSeed) external {
        if (positionIds.length == 0) return;

        uint256 posId = positionIds[positionSeed % positionIds.length];
        PositionManager.Position memory pos = pm.getPosition(posId);
        if (!pos.isActive) return;

        // Check if liquidatable
        if (!marginEngine.isLiquidatable(posId)) return;

        try liquidation.liquidate(posId) {
            ghost_liquidationsPerformed++;
        } catch {
            // Liquidation failed
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ORACLE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the floating rate
    function updateRate(uint256 rateSeed) external {
        uint256 newRate = bound(rateSeed, 0.001e18, 0.50e18);
        rateSource.setSupplyRate(newRate);
        oracle.updateRate();
    }

    /// @notice Warp time forward
    function warpTime(uint256 secondsSeed) external {
        uint256 secondsToWarp = bound(secondsSeed, 1 hours, 30 days);
        vm.warp(block.timestamp + secondsToWarp);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPositionCount() external view returns (uint256) {
        return positionIds.length;
    }

    function getActivePositionCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (pm.getPosition(positionIds[i]).isActive) {
                count++;
            }
        }
    }

    function getTotalActiveMargin() external view returns (uint256 total) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            PositionManager.Position memory pos = pm.getPosition(positionIds[i]);
            if (pos.isActive) {
                total += pos.margin;
            }
        }
    }

    function getTotalActiveNotional() external view returns (uint256 fixedTotal, uint256 floatingTotal) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            PositionManager.Position memory pos = pm.getPosition(positionIds[i]);
            if (pos.isActive) {
                if (pos.isPayingFixed) {
                    fixedTotal += pos.notional;
                } else {
                    floatingTotal += pos.notional;
                }
            }
        }
    }
}
