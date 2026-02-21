// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/core/PositionManager.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

contract SettlementEngineTest is Test {
    SettlementEngine public engine;
    PositionManager public pm;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address trader1 = address(0x1);
    address trader2 = address(0x2);
    address keeper = address(0x3);

    uint256 constant INITIAL_BALANCE = 1_000_000e6;
    uint256 constant NOTIONAL = 100_000e6;
    uint256 constant MARGIN = 10_000e6;
    uint256 constant FIXED_RATE = 0.05e18; // 5%

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy rate oracle with mock source
        rateSource = new MockRateSource(0.05e18, 0.07e18); // 5% supply rate

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate(); // Initialize rate

        // Deploy position manager (with fee recipient)
        pm = new PositionManager(address(usdc), 6, address(this));

        // Deploy settlement engine (1 day interval, with collateral token and fee recipient)
        engine = new SettlementEngine(address(pm), address(oracle), 1 days, address(usdc), address(this));

        // Authorize settlement engine
        pm.setAuthorizedContract(address(engine), true);

        // Setup traders
        usdc.mint(trader1, INITIAL_BALANCE);
        usdc.mint(trader2, INITIAL_BALANCE);

        vm.prank(trader1);
        usdc.approve(address(pm), type(uint256).max);

        vm.prank(trader2);
        usdc.approve(address(pm), type(uint256).max);

        // Mint extra USDC to position manager for settlements
        usdc.mint(address(pm), 100_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SetsCorrectValues() public view {
        assertEq(address(engine.positionManager()), address(pm));
        assertEq(address(engine.rateOracle()), address(oracle));
        assertEq(engine.settlementInterval(), 1 days);
    }

    function test_settle_PayingFixed_FloatingHigher() public {
        // Create position: Pay Fixed 5%, Receive Floating
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true, // paying fixed
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Set floating rate higher (7%)
        rateSource.setSupplyRate(0.07e18);
        oracle.updateRate();

        // Advance time past settlement interval
        vm.warp(block.timestamp + 1 days);

        // Settle
        int256 settlement = engine.settle(posId);

        // Should be positive (floating 7% > fixed 5%)
        assertTrue(settlement > 0, "Settlement should be positive");
    }

    function test_settle_PayingFixed_FloatingLower() public {
        // Create position: Pay Fixed 5%, Receive Floating
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Set floating rate lower (3%)
        rateSource.setSupplyRate(0.03e18);
        oracle.updateRate();

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Settle
        int256 settlement = engine.settle(posId);

        // Should be negative (floating 3% < fixed 5%)
        assertTrue(settlement < 0, "Settlement should be negative");
    }

    function test_settle_ReceivingFixed_FloatingHigher() public {
        // Create position: Pay Floating, Receive Fixed 5%
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            false, // receiving fixed
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Set floating rate higher (7%)
        rateSource.setSupplyRate(0.07e18);
        oracle.updateRate();

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Settle
        int256 settlement = engine.settle(posId);

        // Should be negative (paying floating 7% > receiving fixed 5%)
        assertTrue(settlement < 0, "Settlement should be negative");
    }

    function test_settle_ReceivingFixed_FloatingLower() public {
        // Create position: Pay Floating, Receive Fixed 5%
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            false,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Set floating rate lower (3%)
        rateSource.setSupplyRate(0.03e18);
        oracle.updateRate();

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Settle
        int256 settlement = engine.settle(posId);

        // Should be positive (receiving fixed 5% > paying floating 3%)
        assertTrue(settlement > 0, "Settlement should be positive");
    }

    function test_settle_UpdatesPositionPnL() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        rateSource.setSupplyRate(0.07e18);
        oracle.updateRate();
        vm.warp(block.timestamp + 1 days);

        int256 settlement = engine.settle(posId);

        PositionManager.Position memory pos = pm.getPosition(posId);
        assertEq(pos.accumulatedPnL, int128(settlement));
    }

    function test_settle_UpdatesLastSettlementTime() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        vm.warp(block.timestamp + 1 days);
        engine.settle(posId);

        assertEq(engine.lastSettlementTime(posId), block.timestamp);
    }

    function test_settle_EmitsEvent() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        rateSource.setSupplyRate(0.07e18);
        oracle.updateRate();
        vm.warp(block.timestamp + 1 days);

        // Expect event with correct parameters
        vm.expectEmit(true, false, false, false);
        emit SettlementEngine.PositionSettled(posId, 0, 0, 0, 0);

        engine.settle(posId);
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT TIMING
    //////////////////////////////////////////////////////////////*/

    function test_settle_RevertIfTooSoon() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Get position start time
        PositionManager.Position memory pos = pm.getPosition(posId);
        uint256 nextSettlement = pos.startTime + 1 days;

        // Don't advance time enough (need 1 day for settlement)
        vm.warp(block.timestamp + 12 hours);

        vm.expectRevert(
            abi.encodeWithSelector(
                SettlementEngine.SettlementTooSoon.selector,
                posId,
                nextSettlement
            )
        );
        engine.settle(posId);
    }

    function test_settle_CanSettleAfterInterval() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Advance exactly to interval
        vm.warp(block.timestamp + 1 days);

        // Should succeed
        engine.settle(posId);
    }

    function test_canSettle_ReturnsFalseBeforeInterval() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        assertFalse(engine.canSettle(posId));
    }

    function test_canSettle_ReturnsTrueAfterInterval() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        vm.warp(block.timestamp + 1 days);
        assertTrue(engine.canSettle(posId));
    }

    function test_getTimeToNextSettlement_ReturnsCorrectTime() public {
        uint256 startTime = block.timestamp;

        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Next settlement is at startTime + 1 day
        uint256 nextSettlement = startTime + 1 days;

        // Initially, should return 1 day
        assertEq(engine.getTimeToNextSettlement(posId), 1 days, "Should be 1 day initially");

        // Advance 12 hours
        vm.warp(startTime + 12 hours);
        assertEq(engine.getTimeToNextSettlement(posId), 12 hours, "Should be 12 hours remaining");

        // Advance to exactly settlement time
        vm.warp(nextSettlement);
        assertEq(engine.getTimeToNextSettlement(posId), 0, "Should be 0 at settlement time");
    }

    /*//////////////////////////////////////////////////////////////
                          BATCH SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    function test_batchSettle_SettlesMultiplePositions() public {
        // Create multiple positions
        uint256[] memory posIds = new uint256[](3);

        vm.startPrank(trader1);
        posIds[0] = pm.openPosition(true, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN));
        posIds[1] = pm.openPosition(true, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN));
        posIds[2] = pm.openPosition(false, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN));
        vm.stopPrank();

        // Advance time
        vm.warp(block.timestamp + 1 days);

        // Batch settle
        (uint256 settled, uint256 failed) = engine.batchSettle(posIds);

        assertEq(settled, 3);
        assertEq(failed, 0);
    }

    function test_batchSettle_CountsFailures() public {
        vm.prank(trader1);
        uint256 posId1 = pm.openPosition(true, uint128(NOTIONAL), uint128(FIXED_RATE), 90, uint128(MARGIN));

        uint256[] memory posIds = new uint256[](3);
        posIds[0] = posId1;
        posIds[1] = 999; // Non-existent
        posIds[2] = 998; // Non-existent

        vm.warp(block.timestamp + 1 days);

        (uint256 settled, uint256 failed) = engine.batchSettle(posIds);

        assertEq(settled, 1);
        assertEq(failed, 2);
    }

    function test_batchSettle_EmitsEvent() public {
        uint256[] memory posIds = new uint256[](0);

        vm.expectEmit(true, true, true, true);
        emit SettlementEngine.BatchSettlementCompleted(0, 0);

        engine.batchSettle(posIds);
    }

    /*//////////////////////////////////////////////////////////////
                          MATURITY HANDLING
    //////////////////////////////////////////////////////////////*/

    function test_closeMaturedPosition_Success() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            30, // 30 day maturity
            uint128(MARGIN)
        );

        // Advance past maturity
        vm.warp(block.timestamp + 31 days);

        // Close position
        engine.closeMaturedPosition(posId);

        // Verify closed
        PositionManager.Position memory pos = pm.getPosition(posId);
        assertFalse(pos.isActive);
    }

    function test_closeMaturedPosition_RevertIfNotMatured() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Only advance 30 days (not matured yet)
        vm.warp(block.timestamp + 30 days);

        vm.expectRevert(
            abi.encodeWithSelector(SettlementEngine.PositionNotMatured.selector, posId)
        );
        engine.closeMaturedPosition(posId);
    }

    function test_closeMaturedPosition_EmitsEvent() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            30,
            uint128(MARGIN)
        );

        vm.warp(block.timestamp + 31 days);

        vm.expectEmit(true, false, false, false);
        emit SettlementEngine.PositionMatured(posId, 0);

        engine.closeMaturedPosition(posId);
    }

    /*//////////////////////////////////////////////////////////////
                          PENDING SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    function test_getPendingSettlement_ReturnsCorrectAmount() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true, // pay fixed 5%
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        // Set floating higher
        rateSource.setSupplyRate(0.07e18);
        oracle.updateRate();

        // Advance time
        vm.warp(block.timestamp + 1 days);

        int256 pending = engine.getPendingSettlement(posId);

        // Should be positive since receiving higher floating
        assertTrue(pending > 0);
    }

    function test_getPendingSettlement_ReturnsZeroForInactive() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            30,
            uint128(MARGIN)
        );

        // Close the position
        vm.warp(block.timestamp + 31 days);
        engine.closeMaturedPosition(posId);

        int256 pending = engine.getPendingSettlement(posId);
        assertEq(pending, 0);
    }

    function test_previewSettlement_MatchesActualSettlement() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        uint256 floatingRate = 0.07e18;
        uint256 periodSeconds = 1 days;

        int256 preview = engine.previewSettlement(posId, floatingRate, periodSeconds);

        // Set actual rate and settle
        rateSource.setSupplyRate(floatingRate);
        oracle.updateRate();
        vm.warp(block.timestamp + periodSeconds);

        int256 actual = engine.settle(posId);

        // Should match (or be very close due to timing)
        assertApproxEqAbs(preview, actual, 1e6); // Within 1 USDC
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setSettlementInterval_Success() public {
        engine.setSettlementInterval(12 hours);
        assertEq(engine.settlementInterval(), 12 hours);
    }

    function test_setSettlementInterval_RevertIfZero() public {
        vm.expectRevert(SettlementEngine.InvalidInterval.selector);
        engine.setSettlementInterval(0);
    }

    function test_setSettlementInterval_OnlyOwner() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        engine.setSettlementInterval(12 hours);
    }

    function test_setSettlementInterval_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit SettlementEngine.SettlementIntervalUpdated(12 hours);

        engine.setSettlementInterval(12 hours);
    }

    function test_setPaused_PausesSettlements() public {
        engine.setPaused(true);

        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(SettlementEngine.ContractPaused.selector);
        engine.settle(posId);
    }

    function test_setPaused_UnpausesSettlements() public {
        engine.setPaused(true);
        engine.setPaused(false);

        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            90,
            uint128(MARGIN)
        );

        vm.warp(block.timestamp + 1 days);

        // Should succeed
        engine.settle(posId);
    }

    function test_setPaused_OnlyOwner() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        engine.setPaused(true);
    }

    function test_setPaused_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit SettlementEngine.Paused(true);

        engine.setPaused(true);
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_settle_RevertIfPositionNotActive() public {
        // Try to settle non-existent position
        vm.expectRevert(
            abi.encodeWithSelector(SettlementEngine.PositionNotActive.selector, 999)
        );
        engine.settle(999);
    }

    function test_closeMaturedPosition_RevertIfNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(SettlementEngine.PositionNotActive.selector, 999)
        );
        engine.closeMaturedPosition(999);
    }

    function test_closeMaturedPosition_RevertIfPaused() public {
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE),
            30,
            uint128(MARGIN)
        );

        engine.setPaused(true);
        vm.warp(block.timestamp + 31 days);

        vm.expectRevert(SettlementEngine.ContractPaused.selector);
        engine.closeMaturedPosition(posId);
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT MATH
    //////////////////////////////////////////////////////////////*/

    function test_settlementMath_CorrectCalculation() public {
        // Create position: Pay Fixed 5%, 100k notional, 365-day maturity
        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true,
            uint128(NOTIONAL),
            uint128(FIXED_RATE), // 5%
            365, // Full year maturity
            uint128(MARGIN)
        );

        // Set floating rate to 10% (double the fixed)
        rateSource.setSupplyRate(0.10e18);
        oracle.updateRate();

        // Advance 1 year (matches maturity)
        vm.warp(block.timestamp + 365 days);

        int256 settlement = engine.settle(posId);

        // Expected: floating 10% - fixed 5% = 5% of notional for 1 year
        // 100,000e6 * 5% = 5,000e6 USDC profit
        assertTrue(settlement > 0, "Settlement should be positive");

        // Calculate expected (5% of notional for full year)
        int256 expected = int256(NOTIONAL) * 5 / 100; // 5% of notional = 5000e6
        assertApproxEqRel(uint256(settlement), uint256(expected), 0.01e18); // Within 1%
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_settlement_DirectionCorrect(
        uint256 fixedRateSeed,
        uint256 floatingRateSeed
    ) public {
        // Bound to valid rate range: 1-30% in WAD (0.01e18 to 0.30e18)
        uint128 fixedRate = uint128(bound(fixedRateSeed, 0.01e18, 0.30e18));
        uint256 floatingRate = bound(floatingRateSeed, 0.01e18, 0.30e18);

        vm.prank(trader1);
        uint256 posId = pm.openPosition(
            true, // Pay fixed
            uint128(NOTIONAL),
            fixedRate,
            90,
            uint128(MARGIN)
        );

        rateSource.setSupplyRate(floatingRate);
        oracle.updateRate();
        vm.warp(block.timestamp + 1 days);

        int256 settlement = engine.settle(posId);

        // Pay fixed, receive floating:
        // profit when floating > fixed
        // loss when floating < fixed
        // Note: When rates are very close, settlement may be 0 due to precision
        if (floatingRate > fixedRate) {
            assertTrue(settlement >= 0, "Should profit or break even when floating >= fixed");
        } else if (floatingRate < fixedRate) {
            assertTrue(settlement <= 0, "Should lose or break even when floating <= fixed");
        } else {
            assertEq(settlement, 0, "Should be zero when rates equal");
        }
    }

    function testFuzz_settlement_SymmetricPositions(
        uint64 rateSeed
    ) public {
        uint128 fixedRate = 0.05e18; // 5% fixed
        uint256 floatingRate = bound(rateSeed, 0.01e18, 0.30e18);

        // Create opposite positions
        vm.startPrank(trader1);
        uint256 payFixedPos = pm.openPosition(true, uint128(NOTIONAL), fixedRate, 90, uint128(MARGIN));
        uint256 receiveFixedPos = pm.openPosition(false, uint128(NOTIONAL), fixedRate, 90, uint128(MARGIN));
        vm.stopPrank();

        rateSource.setSupplyRate(floatingRate);
        oracle.updateRate();
        vm.warp(block.timestamp + 1 days);

        int256 settlement1 = engine.settle(payFixedPos);
        int256 settlement2 = engine.settle(receiveFixedPos);

        // Calculate rate difference (allowing for small rounding errors)
        uint256 rateDiff = floatingRate > fixedRate
            ? floatingRate - fixedRate
            : fixedRate - floatingRate;

        // Only check opposite signs when rates differ significantly (more than 0.01%)
        // When rates are nearly equal, rounding can cause both to be 0 or same sign
        if (rateDiff > 0.0001e18) {
            // When rates differ significantly, one profits and one loses
            assertTrue(
                (settlement1 > 0 && settlement2 < 0) || (settlement1 < 0 && settlement2 > 0),
                "Opposite positions should have opposite PnL directions"
            );
        }
        // When rates are nearly equal, both settlements should be close to 0
    }
}
