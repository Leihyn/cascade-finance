// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/risk/MarginEngine.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";
import "../../src/pricing/RateOracle.sol";

/// @title HalmosTests
/// @notice Symbolic tests for formal verification using Halmos
/// @dev Run with: halmos --contract HalmosTests
contract HalmosTests is Test {
    PositionManager public pm;
    MarginEngine public marginEngine;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address alice = address(0x1);
    address bob = address(0x2);
    address feeRecipient = address(0x3);

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        rateSource = new MockRateSource(0.05e18, 0.07e18);

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);

        pm = new PositionManager(address(usdc), 6, feeRecipient);
        marginEngine = new MarginEngine(address(pm), address(oracle));

        // Fund accounts
        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);

        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(pm), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                      POSITION MANAGER PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Total margin should always be non-negative
    /// @custom:halmos --solver-timeout-assertion 300
    function check_totalMarginNonNegative(
        bool isPayingFixed,
        uint128 notional,
        uint128 fixedRate,
        uint32 maturityDays,
        uint128 margin
    ) public {
        // Preconditions
        vm.assume(notional >= 100e6 && notional <= 10_000_000e6);
        vm.assume(fixedRate > 0 && fixedRate <= 0.5e18);
        vm.assume(maturityDays >= 1 && maturityDays <= 365);
        vm.assume(margin >= notional / 10 && margin <= notional);

        // Mint enough USDC
        usdc.mint(alice, margin);

        vm.prank(alice);
        pm.openPosition(isPayingFixed, notional, fixedRate, maturityDays, margin);

        // Property: Total margin should be positive after opening
        assert(pm.totalMargin() > 0);
    }

    /// @notice Adding margin should increase total margin exactly by amount
    /// @custom:halmos --solver-timeout-assertion 300
    function check_addMarginIncreasesTotalMargin(
        uint128 amount
    ) public {
        vm.assume(amount > 0 && amount <= 100_000e6);

        // Open a position first
        usdc.mint(alice, 10_000e6);
        vm.prank(alice);
        uint256 positionId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        uint256 totalBefore = pm.totalMargin();

        // Add margin
        usdc.mint(alice, amount);
        vm.prank(alice);
        pm.addMargin(positionId, amount);

        uint256 totalAfter = pm.totalMargin();

        // Property: Total margin increased by exactly the added amount
        assert(totalAfter == totalBefore + amount);
    }

    /// @notice Position ID should be monotonically increasing
    /// @custom:halmos --solver-timeout-assertion 300
    function check_positionIdMonotonic() public {
        usdc.mint(alice, 20_000e6);

        vm.startPrank(alice);

        uint256 id1 = pm.openPosition(true, 50_000e6, 0.05e18, 90, 10_000e6);
        uint256 id2 = pm.openPosition(false, 50_000e6, 0.05e18, 90, 10_000e6);

        vm.stopPrank();

        // Property: Second position ID is greater than first
        assert(id2 > id1);
    }

    /// @notice Owner of position should match trader
    /// @custom:halmos --solver-timeout-assertion 300
    function check_positionOwnershipCorrect() public {
        usdc.mint(alice, 10_000e6);

        vm.prank(alice);
        uint256 positionId = pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);

        // Property: Alice owns the position
        assert(pm.ownerOf(positionId) == alice);
    }

    /*//////////////////////////////////////////////////////////////
                        MARGIN ENGINE PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Health factor should be positive for adequately margined positions
    /// @custom:halmos --solver-timeout-assertion 300
    function check_healthFactorPositive(
        uint128 margin
    ) public {
        // Margin between 10% and 50% of notional
        vm.assume(margin >= 10_000e6 && margin <= 50_000e6);

        usdc.mint(alice, margin);

        vm.prank(alice);
        uint256 positionId = pm.openPosition(true, 100_000e6, 0.05e18, 90, uint128(margin));

        uint256 healthFactor = marginEngine.getHealthFactor(positionId);

        // Property: Health factor should be positive (WAD scale)
        assert(healthFactor > 0);
    }

    /// @notice Position with maximum margin should not be liquidatable
    /// @custom:halmos --solver-timeout-assertion 300
    function check_highMarginNotLiquidatable() public {
        // 50% margin = 5x leverage (very safe)
        uint128 margin = 50_000e6;
        usdc.mint(alice, margin);

        vm.prank(alice);
        uint256 positionId = pm.openPosition(true, 100_000e6, 0.05e18, 90, margin);

        bool isLiquidatable = marginEngine.isLiquidatable(positionId);

        // Property: High margin position should not be liquidatable initially
        assert(!isLiquidatable);
    }

    /// @notice Minimum initial margin should be enforced
    /// @custom:halmos --solver-timeout-assertion 300
    function check_minimumMarginEnforced(
        uint128 notional,
        uint128 margin
    ) public {
        vm.assume(notional >= 100e6 && notional <= 10_000_000e6);
        vm.assume(margin < notional / 10); // Less than 10% margin

        usdc.mint(alice, margin);

        vm.prank(alice);

        // This should revert because margin is below minimum
        try pm.openPosition(true, notional, 0.05e18, 90, margin) {
            // If it doesn't revert, that's a bug
            assert(false);
        } catch {
            // Expected behavior
            assert(true);
        }
    }

    /*//////////////////////////////////////////////////////////////
                      FIXED POINT MATH PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice wadMul should be commutative
    /// @custom:halmos --solver-timeout-assertion 300
    function check_wadMulCommutative(uint128 a, uint128 b) public pure {
        vm.assume(a > 0 && b > 0);
        vm.assume(a <= 1e27 && b <= 1e27); // Prevent overflow

        uint256 result1 = FixedPointMath.wadMul(a, b);
        uint256 result2 = FixedPointMath.wadMul(b, a);

        // Property: wadMul(a, b) == wadMul(b, a)
        assert(result1 == result2);
    }

    /// @notice wadMul with WAD should be identity
    /// @custom:halmos --solver-timeout-assertion 300
    function check_wadMulIdentity(uint128 a) public pure {
        vm.assume(a > 0 && a <= 1e36);

        uint256 result = FixedPointMath.wadMul(a, 1e18);

        // Property: wadMul(a, WAD) == a
        assert(result == a);
    }

    /// @notice wadDiv(wadMul(a, b), b) should equal a (approximately)
    /// @custom:halmos --solver-timeout-assertion 300
    function check_wadMulDivInverse(uint128 a, uint128 b) public pure {
        vm.assume(a > 0 && b > 1e12); // Avoid division by small numbers
        vm.assume(a <= 1e24 && b <= 1e24); // Prevent overflow

        uint256 product = FixedPointMath.wadMul(a, b);
        uint256 quotient = FixedPointMath.wadDiv(product, b);

        // Property: Should be approximately equal (allowing for rounding)
        uint256 diff = quotient > a ? quotient - a : a - quotient;
        assert(diff <= 1); // At most 1 unit of rounding error
    }

    /*//////////////////////////////////////////////////////////////
                        INVARIANT PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Contract USDC balance should be at least totalMargin
    /// @dev This is a solvency invariant
    /// @custom:halmos --solver-timeout-assertion 300
    function check_solvencyInvariant() public {
        usdc.mint(alice, 30_000e6);

        vm.startPrank(alice);

        // Open multiple positions
        pm.openPosition(true, 100_000e6, 0.05e18, 90, 10_000e6);
        pm.openPosition(false, 100_000e6, 0.05e18, 90, 10_000e6);
        pm.openPosition(true, 50_000e6, 0.05e18, 90, 10_000e6);

        vm.stopPrank();

        uint256 contractBalance = usdc.balanceOf(address(pm));
        uint256 totalMargin = pm.totalMargin();

        // Property: Contract should have at least as much USDC as totalMargin
        assert(contractBalance >= totalMargin);
    }

    /// @notice Active position count should match actual active positions
    /// @custom:halmos --solver-timeout-assertion 300
    function check_activeCountConsistent() public {
        usdc.mint(alice, 20_000e6);

        vm.startPrank(alice);

        uint256 id1 = pm.openPosition(true, 50_000e6, 0.05e18, 90, 10_000e6);
        uint256 id2 = pm.openPosition(false, 50_000e6, 0.05e18, 90, 10_000e6);

        vm.stopPrank();

        uint256 activeCount = pm.activePositionCount();

        // Property: Active count should be 2
        assert(activeCount == 2);
    }
}
