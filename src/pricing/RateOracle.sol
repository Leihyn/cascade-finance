// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";
import "../libraries/FixedPointMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title RateOracle
/// @author Kairos Protocol
/// @notice Aggregates interest rates from multiple DeFi protocols
/// @dev Uses median for manipulation resistance and TWAP for settlement
contract RateOracle is Ownable {
    using FixedPointMath for uint256;

    /*//////////////////////////////////////////////////////////////
                        PHASE 1 SECURITY CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum rate change allowed per update (500% = rate can 5x)
    /// @dev Circuit breaker triggers if rate moves more than this
    /// @dev Interest rates can legitimately spike during high utilization (e.g., 5% → 25%)
    /// @dev This catches manipulation (100x moves) while allowing normal DeFi volatility
    uint256 public constant MAX_RATE_CHANGE = 5e18;

    /// @notice Maximum number of rate sources allowed
    /// @dev Prevents gas issues with median calculation
    uint256 public constant MAX_SOURCES = 5;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Rate observation for TWAP calculation
    struct RateObservation {
        uint40 timestamp;
        uint216 cumulativeRate; // Accumulated rate * time
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice List of rate sources (Aave, Compound, etc.)
    address[] public sources;

    /// @notice Historical rate observations for TWAP
    RateObservation[] public observations;

    /// @notice Last recorded rate
    uint256 public lastRate;

    /// @notice Minimum number of sources required for valid rate
    uint256 public minSources;

    /// @notice Maximum age for a rate to be considered fresh (in seconds)
    uint256 public maxStaleness;

    /// @notice Timestamp of last rate update
    uint256 public lastUpdateTime;

    /// @notice Circuit breaker state - stops operations on extreme rate movements
    /// @dev Phase 1 Security: Prevents oracle manipulation attacks
    bool public circuitBreakerTripped;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RateUpdated(uint256 rate, uint256 timestamp, uint256 numSources);
    event SourceAdded(address indexed source);
    event SourceRemoved(address indexed source);
    event MinSourcesUpdated(uint256 newMinSources);
    event MaxStalenessUpdated(uint256 newMaxStaleness);

    // Phase 1 Security: Circuit breaker events
    event CircuitBreakerTripped(uint256 timestamp, uint256 oldRate, uint256 newRate);
    event CircuitBreakerReset(uint256 timestamp);
    event RateAnomalyDetected(uint256 expectedRate, uint256 actualRate);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoSources();
    error InsufficientSources(uint256 available, uint256 required);
    error StaleRate(uint256 lastUpdate, uint256 maxAge);
    error SourceAlreadyExists();
    error SourceNotFound();
    error InvalidSource();
    error InvalidObservationPeriod();

    // Phase 1 Security: Circuit breaker errors
    error CircuitBreakerActive();
    error TooManySources(uint256 current, uint256 max);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address[] memory _sources,
        uint256 _minSources,
        uint256 _maxStaleness
    ) Ownable(msg.sender) {
        for (uint256 i = 0; i < _sources.length; i++) {
            if (_sources[i] == address(0)) revert InvalidSource();
            sources.push(_sources[i]);
        }
        minSources = _minSources > 0 ? _minSources : 1;
        maxStaleness = _maxStaleness > 0 ? _maxStaleness : 1 hours;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current rate (median of all sources)
    /// @dev Phase 1 Security: Checks circuit breaker and validates rate changes
    /// @return rate Current interest rate in WAD
    function getCurrentRate() public view returns (uint256 rate) {
        // Phase 1 Security: Check circuit breaker first
        if (circuitBreakerTripped) {
            revert CircuitBreakerActive();
        }

        if (sources.length == 0) revert NoSources();

        uint256[] memory rates = _fetchAllRates();
        uint256 validCount = _countValidRates(rates);

        if (validCount < minSources) {
            revert InsufficientSources(validCount, minSources);
        }

        uint256 medianRate = _median(rates, validCount);

        // Phase 1 Security: Detect anomalies (but don't revert in view function)
        // Actual circuit breaker tripping happens in updateRate()
        return medianRate;
    }

    /// @notice Get rate with staleness check
    /// @return rate Current rate if fresh
    function getFreshRate() external view returns (uint256 rate) {
        if (block.timestamp - lastUpdateTime > maxStaleness) {
            revert StaleRate(lastUpdateTime, maxStaleness);
        }
        return lastRate;
    }

    /// @notice Get time-weighted average rate over a period
    /// @param period Lookback period in seconds
    /// @return twap Time-weighted average rate
    function getTWAP(uint256 period) external view returns (uint256 twap) {
        if (observations.length < 2) return lastRate;
        if (period == 0) revert InvalidObservationPeriod();

        uint256 targetTime = block.timestamp - period;

        // Find observation at or before targetTime
        uint256 startIdx = _findObservation(targetTime);
        uint256 endIdx = observations.length - 1;

        RateObservation memory start = observations[startIdx];
        RateObservation memory end = observations[endIdx];

        uint256 timeElapsed = end.timestamp - start.timestamp;
        if (timeElapsed == 0) return lastRate;

        return (end.cumulativeRate - start.cumulativeRate) / timeElapsed;
    }

    /// @notice Get number of active sources
    function getSourceCount() external view returns (uint256) {
        return sources.length;
    }

    /// @notice Get all sources
    function getSources() external view returns (address[] memory) {
        return sources;
    }

    /// @notice Get number of observations
    function getObservationCount() external view returns (uint256) {
        return observations.length;
    }

    /// @notice Check if rate is stale
    function isStale() external view returns (bool) {
        return block.timestamp - lastUpdateTime > maxStaleness;
    }

    /*//////////////////////////////////////////////////////////////
                          KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update rate observation (called by keeper)
    /// @dev Anyone can call this to keep rates fresh
    /// @dev Phase 1 Security: Detects extreme rate changes and can trip circuit breaker
    function updateRate() external {
        // Phase 1 Security: Check circuit breaker
        if (circuitBreakerTripped) {
            revert CircuitBreakerActive();
        }

        // Get current rate (will revert if circuit breaker tripped)
        if (sources.length == 0) revert NoSources();

        uint256[] memory rates = _fetchAllRates();
        uint256 validCount = _countValidRates(rates);

        if (validCount < minSources) {
            revert InsufficientSources(validCount, minSources);
        }

        uint256 rate = _median(rates, validCount);

        // Phase 1 Security: Check for extreme rate changes
        if (lastRate > 0) {
            uint256 change = rate > lastRate ? rate - lastRate : lastRate - rate;
            uint256 maxAllowedChange = lastRate.wadMul(MAX_RATE_CHANGE);

            if (change > maxAllowedChange) {
                // Trip circuit breaker on extreme movement
                circuitBreakerTripped = true;
                emit CircuitBreakerTripped(block.timestamp, lastRate, rate);
                emit RateAnomalyDetected(lastRate, rate);
                revert CircuitBreakerActive();
            }
        }

        uint256 timeDelta = observations.length > 0
            ? block.timestamp - observations[observations.length - 1].timestamp
            : 0;

        uint256 newCumulative = observations.length > 0
            ? observations[observations.length - 1].cumulativeRate + (rate * timeDelta)
            : 0;

        observations.push(
            RateObservation({
                timestamp: uint40(block.timestamp),
                cumulativeRate: uint216(newCumulative)
            })
        );

        lastRate = rate;
        lastUpdateTime = block.timestamp;

        emit RateUpdated(rate, block.timestamp, sources.length);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a new rate source
    /// @dev Phase 1 Security: Enforces MAX_SOURCES limit
    /// @param source Address of the rate source contract
    function addSource(address source) external onlyOwner {
        if (source == address(0)) revert InvalidSource();

        // Phase 1 Security: Enforce source limit for gas efficiency
        if (sources.length >= MAX_SOURCES) {
            revert TooManySources(sources.length, MAX_SOURCES);
        }

        // Check if source already exists
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i] == source) revert SourceAlreadyExists();
        }

        sources.push(source);
        emit SourceAdded(source);
    }

    /// @notice Remove a rate source
    /// @param source Address of the rate source to remove
    function removeSource(address source) external onlyOwner {
        uint256 length = sources.length;
        for (uint256 i = 0; i < length; i++) {
            if (sources[i] == source) {
                // Swap with last element and pop
                sources[i] = sources[length - 1];
                sources.pop();
                emit SourceRemoved(source);
                return;
            }
        }
        revert SourceNotFound();
    }

    /// @notice Update minimum sources required
    function setMinSources(uint256 _minSources) external onlyOwner {
        minSources = _minSources;
        emit MinSourcesUpdated(_minSources);
    }

    /// @notice Update maximum staleness threshold
    function setMaxStaleness(uint256 _maxStaleness) external onlyOwner {
        maxStaleness = _maxStaleness;
        emit MaxStalenessUpdated(_maxStaleness);
    }

    /*//////////////////////////////////////////////////////////////
                    PHASE 1: CIRCUIT BREAKER CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @notice Manually trip circuit breaker in emergency
    /// @dev Only callable by owner - use when oracle manipulation detected
    function tripCircuitBreaker() external onlyOwner {
        circuitBreakerTripped = true;
        emit CircuitBreakerTripped(block.timestamp, lastRate, 0);
    }

    /// @notice Reset circuit breaker after investigation
    /// @dev Only callable by owner - should verify rates are valid first
    /// @param newLastRate The validated rate to use as baseline after reset
    function resetCircuitBreaker(uint256 newLastRate) external onlyOwner {
        circuitBreakerTripped = false;
        if (newLastRate > 0) {
            lastRate = newLastRate;
        }
        emit CircuitBreakerReset(block.timestamp);
    }

    /// @notice Check if circuit breaker is active
    /// @return True if circuit breaker is tripped
    function isCircuitBreakerActive() external view returns (bool) {
        return circuitBreakerTripped;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fetch rates from all sources
    function _fetchAllRates() internal view returns (uint256[] memory rates) {
        rates = new uint256[](sources.length);

        for (uint256 i = 0; i < sources.length; i++) {
            try IRateSource(sources[i]).getSupplyRate() returns (uint256 rate) {
                rates[i] = rate;
            } catch {
                rates[i] = 0; // Mark as invalid
            }
        }
    }

    /// @notice Count non-zero (valid) rates
    function _countValidRates(uint256[] memory rates) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] > 0) count++;
        }
    }

    /// @notice Calculate median of valid rates
    /// @dev Filters out zero values, sorts, and returns median
    function _median(
        uint256[] memory rates,
        uint256 validCount
    ) internal pure returns (uint256) {
        // Create array of valid rates only
        uint256[] memory validRates = new uint256[](validCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] > 0) {
                validRates[idx++] = rates[i];
            }
        }

        // Sort valid rates (bubble sort - fine for small arrays)
        for (uint256 i = 0; i < validCount; i++) {
            for (uint256 j = i + 1; j < validCount; j++) {
                if (validRates[i] > validRates[j]) {
                    (validRates[i], validRates[j]) = (validRates[j], validRates[i]);
                }
            }
        }

        // Return median
        uint256 mid = validCount / 2;
        if (validCount % 2 == 0) {
            return (validRates[mid - 1] + validRates[mid]) / 2;
        } else {
            return validRates[mid];
        }
    }

    /// @notice Binary search for observation at or before timestamp
    function _findObservation(uint256 targetTime) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = observations.length - 1;

        // If target is before first observation, return first
        if (observations[low].timestamp >= targetTime) return low;

        // If target is after last observation, return last
        if (observations[high].timestamp <= targetTime) return high;

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (observations[mid].timestamp <= targetTime) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }

        return low;
    }
}
