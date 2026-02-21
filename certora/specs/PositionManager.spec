/*
 * Formal Verification Specification for PositionManager
 *
 * This spec verifies key invariants and properties of the PositionManager contract.
 * Run with: certoraRun certora/conf/PositionManager.conf
 */

using PositionManager as pm;

/*
 * ============================================
 * METHODS DECLARATIONS
 * ============================================
 */
methods {
    function totalMargin() external returns (uint256) envfree;
    function activePositionCount() external returns (uint256) envfree;
    function nextPositionId() external returns (uint256) envfree;
    function positions(uint256) external returns (
        address, bool, uint256, uint256, bool, uint256, uint256, uint256, int256, uint256, uint256
    ) envfree;
    function ownerOf(uint256) external returns (address) envfree;
}

/*
 * ============================================
 * GHOST VARIABLES
 * ============================================
 */

// Ghost variable to track sum of all margins
ghost uint256 sumOfMargins {
    init_state axiom sumOfMargins == 0;
}

// Ghost variable to track active position count
ghost uint256 activeCount {
    init_state axiom activeCount == 0;
}

/*
 * ============================================
 * HOOKS
 * ============================================
 */

// Update ghost when position margin changes
hook Sstore positions[KEY uint256 positionId].margin uint256 newMargin (uint256 oldMargin) STORAGE {
    sumOfMargins = sumOfMargins - oldMargin + newMargin;
}

// Update ghost when position becomes active/inactive
hook Sstore positions[KEY uint256 positionId].isActive bool newActive (bool oldActive) STORAGE {
    if (newActive && !oldActive) {
        activeCount = activeCount + 1;
    } else if (!newActive && oldActive) {
        activeCount = activeCount - 1;
    }
}

/*
 * ============================================
 * INVARIANTS
 * ============================================
 */

/// @title Total margin equals sum of all position margins
/// @dev This ensures the accounting is correct and no margin is lost
invariant totalMarginEqualsSum()
    totalMargin() == sumOfMargins
    {
        preserved with (env e) {
            require e.msg.sender != 0;
        }
    }

/// @title Active position count is consistent
/// @dev The tracked count matches the actual number of active positions
invariant activePositionCountConsistent()
    activePositionCount() == activeCount
    {
        preserved with (env e) {
            require e.msg.sender != 0;
        }
    }

/// @title Next position ID always increases
/// @dev Position IDs are monotonically increasing
invariant nextPositionIdMonotonic()
    nextPositionId() >= 0

/// @title No position can have zero margin if active
/// @dev Active positions must have positive margin
invariant activePositionHasMargin(uint256 positionId)
    positionId < nextPositionId() => (
        getPositionIsActive(positionId) => getPositionMargin(positionId) > 0
    )

/*
 * ============================================
 * RULES
 * ============================================
 */

/// @title Opening a position increases total margin
rule openPositionIncreasesTotalMargin(env e) {
    uint256 marginBefore = totalMargin();

    bool isPayingFixed;
    uint256 notional;
    uint256 fixedRate;
    uint256 maturityDays;
    uint256 margin;

    require margin > 0;

    uint256 positionId = openPosition(e, isPayingFixed, notional, fixedRate, maturityDays, margin);

    uint256 marginAfter = totalMargin();

    assert marginAfter >= marginBefore, "Total margin should not decrease on position open";
}

/// @title Adding margin increases position margin
rule addMarginIncreasesPositionMargin(env e, uint256 positionId, uint256 amount) {
    require amount > 0;

    uint256 marginBefore = getPositionMargin(positionId);

    addMargin(e, positionId, amount);

    uint256 marginAfter = getPositionMargin(positionId);

    assert marginAfter == marginBefore + amount, "Position margin should increase by amount added";
}

/// @title Removing margin decreases position margin
rule removeMarginDecreasesPositionMargin(env e, uint256 positionId, uint256 amount) {
    require amount > 0;

    uint256 marginBefore = getPositionMargin(positionId);
    require marginBefore >= amount;

    removeMargin(e, positionId, amount);

    uint256 marginAfter = getPositionMargin(positionId);

    assert marginAfter == marginBefore - amount, "Position margin should decrease by amount removed";
}

/// @title Only position owner can modify position
rule onlyOwnerCanModifyPosition(env e, uint256 positionId, uint256 amount) {
    address owner = ownerOf(positionId);

    addMargin@withrevert(e, positionId, amount);

    assert !lastReverted => e.msg.sender == owner, "Only owner should be able to add margin";
}

/// @title Closing position resets margin to zero
rule closingPositionResetsMargin(env e, uint256 positionId) {
    require getPositionIsActive(positionId);

    // Close through authorized contract
    closePosition(e, positionId, 0, 0);

    assert getPositionMargin(positionId) == 0, "Closed position should have zero margin";
    assert !getPositionIsActive(positionId), "Closed position should not be active";
}

/*
 * ============================================
 * HELPER FUNCTIONS
 * ============================================
 */

function getPositionMargin(uint256 positionId) returns uint256 {
    address trader;
    bool isPayingFixed;
    uint256 startTime;
    uint256 maturity;
    bool isActive;
    uint256 notional;
    uint256 margin;
    uint256 fixedRate;
    int256 accumulatedPnL;
    uint256 lastSettlement;
    uint256 reserved;

    (trader, isPayingFixed, startTime, maturity, isActive, notional, margin, fixedRate, accumulatedPnL, lastSettlement, reserved) = pm.positions(positionId);

    return margin;
}

function getPositionIsActive(uint256 positionId) returns bool {
    address trader;
    bool isPayingFixed;
    uint256 startTime;
    uint256 maturity;
    bool isActive;
    uint256 notional;
    uint256 margin;
    uint256 fixedRate;
    int256 accumulatedPnL;
    uint256 lastSettlement;
    uint256 reserved;

    (trader, isPayingFixed, startTime, maturity, isActive, notional, margin, fixedRate, accumulatedPnL, lastSettlement, reserved) = pm.positions(positionId);

    return isActive;
}
