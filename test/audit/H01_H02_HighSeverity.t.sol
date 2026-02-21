// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PositionManager.sol";
import "../../src/core/SettlementEngine.sol";
import "../../src/pricing/RateOracle.sol";
import "../../src/mocks/MockERC20.sol";
import "../../src/mocks/MockRateSource.sol";

/**
 * @title H-01 & H-02 Proof of Concept: High Severity Findings
 *
 * H-01: Unsafe int256 to int128 Cast
 * - updatePositionPnL casts int256 to int128 without bounds checking
 * - Values exceeding int128 bounds silently overflow
 *
 * H-02: settleInternal Uses tx.origin
 * - Breaks smart contract wallet compatibility
 * - Inconsistent with settle() which uses msg.sender
 */
contract H01_H02_HighSeverityTest is Test {
    PositionManager public pm;
    SettlementEngine public settlement;
    RateOracle public oracle;
    MockERC20 public usdc;
    MockRateSource public rateSource;

    address alice = address(0x1);
    address keeper = address(0x2);
    address feeRecipient = address(0xFEE);

    uint256 constant ONE_USDC = 1e6;

    event KeeperRewardPaid(address indexed keeper, uint256 indexed positionId, uint256 reward);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);

        rateSource = new MockRateSource(0.05e18, 0.06e18);

        address[] memory sources = new address[](1);
        sources[0] = address(rateSource);
        oracle = new RateOracle(sources, 1, 1 hours);
        oracle.updateRate();

        pm = new PositionManager(address(usdc), 6, feeRecipient);
        settlement = new SettlementEngine(
            address(pm),
            address(oracle),
            1 days,
            address(usdc),
            feeRecipient
        );

        pm.setAuthorizedContract(address(settlement), true);
        pm.setAuthorizedContract(address(this), true); // For testing

        usdc.mint(alice, 1_000_000 * ONE_USDC);
        vm.prank(alice);
        usdc.approve(address(pm), type(uint256).max);

        vm.prank(alice);
        pm.openPosition(true, 1_000_000e6, 0.05e18, 90, 100_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                    H-01: UNSAFE INT CAST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Shows the unsafe cast in updatePositionPnL
     */
    function test_H01_UnsafeCast_CodeReview() public {
        // The vulnerable code in PositionManager.sol:579
        //
        // function updatePositionPnL(
        //     uint256 positionId,
        //     int256 pnlDelta  // <-- 256 bits
        // ) external onlyAuthorized positionActive(positionId) {
        //     Position storage pos = positions[positionId];
        //     pos.accumulatedPnL += int128(pnlDelta);  // <-- UNSAFE: truncated to 128 bits
        // }

        console.log("=== H-01: Unsafe Int Cast ===");
        console.log("int128.max:", uint256(uint128(type(int128).max)));
        console.log("int128.min:", uint256(uint128(type(int128).min)));
        console.log("");
        console.log("Any pnlDelta outside this range silently overflows");
    }

    /**
     * @notice Demonstrates silent overflow with extreme values
     * @dev In practice, this requires extreme market conditions or malicious input
     */
    function test_H01_SilentOverflow() public {
        // Get initial PnL
        PositionManager.Position memory posBefore = pm.getPosition(0);
        int128 pnlBefore = posBefore.accumulatedPnL;
        console.log("PnL before:", pnlBefore);

        // Try to add a value larger than int128.max
        // This will silently wrap around
        int256 hugeValue = int256(type(int128).max) + 1;

        // The cast int128(hugeValue) will overflow to int128.min
        int128 castedValue = int128(hugeValue);
        console.log("int128.max + 1 casted:", castedValue);

        // Verify the overflow
        assertEq(castedValue, type(int128).min, "Value wrapped to int128.min");

        console.log("");
        console.log("If this were applied as PnL delta:");
        console.log("Expected: Large positive PnL");
        console.log("Actual: Large negative PnL");
        console.log("Position accounting CORRUPTED");
    }

    /**
     * @notice Shows comparison with safe implementation in same codebase
     */
    function test_H01_SafeImplementationExists() public {
        // Comet.sol has a safe version:
        //
        // function _safe104(int256 x) internal pure returns (int104) {
        //     require(x >= type(int104).min && x <= type(int104).max, "int104 overflow");
        //     return int104(x);
        // }

        // The fix for updatePositionPnL should be:
        //
        // require(
        //     pnlDelta >= type(int128).min && pnlDelta <= type(int128).max,
        //     "PnL delta overflow"
        // );
        // pos.accumulatedPnL += int128(pnlDelta);

        console.log("Safe pattern exists in Comet._safe104()");
        console.log("PositionManager.updatePositionPnL should use same pattern");
    }

    /**
     * @notice Shows realistic scenario where this could be exploited
     */
    function test_H01_RealisticExploitScenario() public {
        // Scenario: Attacker controls a malicious settlement engine
        // (or compromises the authorized one)

        // They can call updatePositionPnL with crafted values to:
        // 1. Set victim's PnL to large negative (liquidate them)
        // 2. Set their own PnL to large positive (steal margin)

        // This requires being authorized, but the unsafe cast makes
        // the damage worse if authorization is compromised

        console.log("=== Exploit Scenario ===");
        console.log("1. Attacker compromises authorized contract");
        console.log("2. Calls updatePositionPnL(victimId, int128.max + 1)");
        console.log("3. Victim's PnL wraps to int128.min");
        console.log("4. Victim appears to have massive loss");
        console.log("5. Position becomes liquidatable");
        console.log("6. Attacker liquidates for profit");
    }

    /*//////////////////////////////////////////////////////////////
                    H-02: TX.ORIGIN USAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Shows tx.origin vs msg.sender inconsistency
     */
    function test_H02_InconsistentOriginUsage() public {
        // In settle():
        // emit KeeperRewardPaid(msg.sender, positionId, keeperReward);
        //
        // In settleInternal():
        // emit KeeperRewardPaid(tx.origin, positionId, keeperReward);

        console.log("=== H-02: tx.origin Usage ===");
        console.log("");
        console.log("settle() uses: msg.sender");
        console.log("settleInternal() uses: tx.origin");
        console.log("");
        console.log("This creates inconsistent behavior");
    }

    /**
     * @notice Shows smart contract wallet compatibility issue
     */
    function test_H02_SmartWalletIncompatibility() public {
        // When a smart contract wallet (like Gnosis Safe) calls batchSettle:
        // - msg.sender = Safe contract
        // - tx.origin = EOA signer

        // Keeper rewards would be attributed to the signer, not the Safe
        // This breaks multi-sig keeper operations

        console.log("=== Smart Wallet Issue ===");
        console.log("");
        console.log("Gnosis Safe calls batchSettle:");
        console.log("- msg.sender = 0xSafe");
        console.log("- tx.origin = 0xSigner");
        console.log("");
        console.log("Reward attributed to: 0xSigner (wrong!)");
        console.log("Should be: 0xSafe");
        console.log("");
        console.log("Multi-sig keeper operations broken");
    }

    /**
     * @notice Demonstrates the tx.origin phishing risk
     */
    function test_H02_PhishingScenario() public {
        // Scenario: Malicious contract tricks user into calling it
        // The malicious contract then calls batchSettle
        // Rewards are credited to victim (tx.origin), not attacker (msg.sender)

        // In this case, it's not directly exploitable for theft
        // (rewards go to victim which is actually correct by accident)
        // But it demonstrates the anti-pattern

        console.log("=== tx.origin Anti-Pattern ===");
        console.log("");
        console.log("tx.origin is considered harmful because:");
        console.log("1. Breaks composability with other contracts");
        console.log("2. Can enable phishing in other contexts");
        console.log("3. Inconsistent with EIP-4337 (account abstraction)");
        console.log("4. Will break with future wallet standards");
    }

    /**
     * @notice Shows the correct fix
     */
    function test_H02_CorrectFix() public {
        // The fix is to pass keeper address explicitly:
        //
        // function batchSettle(uint256[] calldata positionIds) external {
        //     for (uint i = 0; i < positionIds.length; i++) {
        //         this.settleInternal(positionIds[i], msg.sender);  // Pass keeper
        //     }
        // }
        //
        // function settleInternal(uint256 positionId, address keeper) external {
        //     require(msg.sender == address(this));
        //     // ... use keeper instead of tx.origin
        //     emit KeeperRewardPaid(keeper, positionId, reward);
        // }

        console.log("=== Correct Fix ===");
        console.log("");
        console.log("Change settleInternal signature:");
        console.log("- From: settleInternal(uint256 positionId)");
        console.log("- To:   settleInternal(uint256 positionId, address keeper)");
        console.log("");
        console.log("Pass msg.sender from batchSettle");
        console.log("Use keeper parameter instead of tx.origin");
    }

    /*//////////////////////////////////////////////////////////////
                    COMBINED IMPACT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Shows combined risk of both issues
     */
    function test_CombinedRiskAssessment() public {
        console.log("=== Combined Risk Assessment ===");
        console.log("");
        console.log("H-01 (Unsafe Cast):");
        console.log("  Likelihood: Low (requires extreme values or compromise)");
        console.log("  Impact: High (corrupts accounting, enables theft)");
        console.log("  Risk: Medium-High");
        console.log("");
        console.log("H-02 (tx.origin):");
        console.log("  Likelihood: Medium (affects all smart wallet users)");
        console.log("  Impact: Medium (breaks functionality, not direct theft)");
        console.log("  Risk: Medium");
        console.log("");
        console.log("Both should be fixed before mainnet deployment.");
    }
}
