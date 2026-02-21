// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockRateSource.sol";

contract RateOracleTest is Test {
    RateOracle public oracle;
    MockRateSource public source1;
    MockRateSource public source2;
    MockRateSource public source3;

    address owner = address(this);

    function setUp() public {
        // Create mock rate sources with different rates
        source1 = new MockRateSource(0.05e18, 0.07e18); // 5% supply, 7% borrow
        source2 = new MockRateSource(0.06e18, 0.08e18); // 6% supply, 8% borrow
        source3 = new MockRateSource(0.04e18, 0.06e18); // 4% supply, 6% borrow

        address[] memory sources = new address[](3);
        sources[0] = address(source1);
        sources[1] = address(source2);
        sources[2] = address(source3);

        oracle = new RateOracle(sources, 1, 1 hours);
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SetsSources() public view {
        assertEq(oracle.getSourceCount(), 3);
    }

    function test_constructor_SetsMinSources() public view {
        assertEq(oracle.minSources(), 1);
    }

    function test_constructor_SetsMaxStaleness() public view {
        assertEq(oracle.maxStaleness(), 1 hours);
    }

    function test_getCurrentRate_ReturnsMedian() public view {
        // Rates: 4%, 5%, 6% → median should be 5%
        uint256 rate = oracle.getCurrentRate();
        assertEq(rate, 0.05e18);
    }

    function test_getCurrentRate_TwoSources_ReturnsAverage() public {
        // Remove one source to test even number median
        oracle.removeSource(address(source3));

        // Rates: 5%, 6% → average should be 5.5%
        uint256 rate = oracle.getCurrentRate();
        assertEq(rate, 0.055e18);
    }

    function test_getCurrentRate_SingleSource() public {
        oracle.removeSource(address(source2));
        oracle.removeSource(address(source3));

        uint256 rate = oracle.getCurrentRate();
        assertEq(rate, 0.05e18);
    }

    /*//////////////////////////////////////////////////////////////
                            RATE UPDATES
    //////////////////////////////////////////////////////////////*/

    function test_updateRate_RecordsObservation() public {
        oracle.updateRate();

        assertEq(oracle.getObservationCount(), 1);
        assertEq(oracle.lastRate(), 0.05e18);
        assertEq(oracle.lastUpdateTime(), block.timestamp);
    }

    function test_updateRate_MultipleUpdates() public {
        oracle.updateRate();
        assertEq(oracle.getObservationCount(), 1);

        // Advance time
        vm.warp(block.timestamp + 1 hours);

        oracle.updateRate();
        assertEq(oracle.getObservationCount(), 2);
    }

    function test_updateRate_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RateOracle.RateUpdated(0.05e18, block.timestamp, 3);
        oracle.updateRate();
    }

    /*//////////////////////////////////////////////////////////////
                              TWAP
    //////////////////////////////////////////////////////////////*/

    function test_getTWAP_SingleObservation_ReturnsLastRate() public {
        oracle.updateRate();
        uint256 twap = oracle.getTWAP(1 hours);
        assertEq(twap, oracle.lastRate());
    }

    function test_getTWAP_MultipleObservations() public {
        // First observation at 5%
        oracle.updateRate();
        uint256 time1 = block.timestamp;

        // Advance 1 hour, change rate to 6%
        vm.warp(block.timestamp + 1 hours);
        source1.setSupplyRate(0.06e18);
        source2.setSupplyRate(0.07e18);
        source3.setSupplyRate(0.05e18);
        oracle.updateRate();

        // TWAP over the period
        uint256 twap = oracle.getTWAP(1 hours);

        // Should be weighted average
        assertTrue(twap > 0);
    }

    /*//////////////////////////////////////////////////////////////
                           STALENESS
    //////////////////////////////////////////////////////////////*/

    function test_isStale_FreshRate() public {
        oracle.updateRate();
        assertFalse(oracle.isStale());
    }

    function test_isStale_StaleRate() public {
        oracle.updateRate();
        vm.warp(block.timestamp + 2 hours);
        assertTrue(oracle.isStale());
    }

    function test_getFreshRate_RevertIfStale() public {
        oracle.updateRate();
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(
                RateOracle.StaleRate.selector,
                block.timestamp - 2 hours,
                1 hours
            )
        );
        oracle.getFreshRate();
    }

    function test_getFreshRate_Success() public {
        oracle.updateRate();
        uint256 rate = oracle.getFreshRate();
        assertEq(rate, 0.05e18);
    }

    /*//////////////////////////////////////////////////////////////
                          SOURCE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_addSource_Success() public {
        MockRateSource newSource = new MockRateSource(0.07e18, 0.09e18);

        vm.expectEmit(true, true, true, true);
        emit RateOracle.SourceAdded(address(newSource));

        oracle.addSource(address(newSource));
        assertEq(oracle.getSourceCount(), 4);
    }

    function test_addSource_RevertIfZeroAddress() public {
        vm.expectRevert(RateOracle.InvalidSource.selector);
        oracle.addSource(address(0));
    }

    function test_addSource_RevertIfDuplicate() public {
        vm.expectRevert(RateOracle.SourceAlreadyExists.selector);
        oracle.addSource(address(source1));
    }

    function test_addSource_OnlyOwner() public {
        MockRateSource newSource = new MockRateSource(0.07e18, 0.09e18);

        vm.prank(address(0x1234));
        vm.expectRevert();
        oracle.addSource(address(newSource));
    }

    function test_removeSource_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RateOracle.SourceRemoved(address(source2));

        oracle.removeSource(address(source2));
        assertEq(oracle.getSourceCount(), 2);
    }

    function test_removeSource_RevertIfNotFound() public {
        vm.expectRevert(RateOracle.SourceNotFound.selector);
        oracle.removeSource(address(0x9999));
    }

    function test_removeSource_OnlyOwner() public {
        vm.prank(address(0x1234));
        vm.expectRevert();
        oracle.removeSource(address(source1));
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setMinSources() public {
        oracle.setMinSources(2);
        assertEq(oracle.minSources(), 2);
    }

    function test_setMaxStaleness() public {
        oracle.setMaxStaleness(2 hours);
        assertEq(oracle.maxStaleness(), 2 hours);
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR CASES
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentRate_RevertNoSources() public {
        // Remove all sources
        oracle.removeSource(address(source1));
        oracle.removeSource(address(source2));
        oracle.removeSource(address(source3));

        vm.expectRevert(RateOracle.NoSources.selector);
        oracle.getCurrentRate();
    }

    function test_getCurrentRate_RevertInsufficientSources() public {
        // Set min sources higher than available valid sources
        oracle.setMinSources(5);

        vm.expectRevert(
            abi.encodeWithSelector(RateOracle.InsufficientSources.selector, 3, 5)
        );
        oracle.getCurrentRate();
    }

    function test_getTWAP_RevertZeroPeriod() public {
        // Need at least 2 observations for the zero period check to trigger
        oracle.updateRate();
        vm.warp(block.timestamp + 1 hours);
        oracle.updateRate();

        vm.expectRevert(RateOracle.InvalidObservationPeriod.selector);
        oracle.getTWAP(0);
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getCurrentRate_AlwaysReturnsValidRate(
        uint64 rate1,
        uint64 rate2,
        uint64 rate3
    ) public {
        vm.assume(rate1 > 0 && rate1 <= 1e18);
        vm.assume(rate2 > 0 && rate2 <= 1e18);
        vm.assume(rate3 > 0 && rate3 <= 1e18);

        source1.setSupplyRate(rate1);
        source2.setSupplyRate(rate2);
        source3.setSupplyRate(rate3);

        uint256 rate = oracle.getCurrentRate();

        // Rate should be between min and max of inputs
        uint256 minRate = rate1 < rate2 ? (rate1 < rate3 ? rate1 : rate3) : (rate2 < rate3 ? rate2 : rate3);
        uint256 maxRate = rate1 > rate2 ? (rate1 > rate3 ? rate1 : rate3) : (rate2 > rate3 ? rate2 : rate3);

        assertTrue(rate >= minRate && rate <= maxRate);
    }

    function testFuzz_medianIsManipulationResistant(uint64 honesPrate, uint64 maliciousRate) public {
        vm.assume(honesPrate > 0 && honesPrate <= 0.20e18); // Max 20%
        vm.assume(maliciousRate > 0);

        // Two honest sources with similar rates
        source1.setSupplyRate(honesPrate);
        source2.setSupplyRate(honesPrate + 0.01e18);

        // One malicious source with extreme rate
        source3.setSupplyRate(maliciousRate);

        uint256 rate = oracle.getCurrentRate();

        // Median should be close to honest rate, not manipulated
        // With 3 sources, median is the middle value
        assertTrue(rate <= honesPrate + 0.01e18);
    }
}
