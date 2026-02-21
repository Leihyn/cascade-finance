// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";

/// @title IComet
/// @notice Minimal interface for Compound V3 (Comet)
interface IComet {
    /// @notice Get the current supply rate per second
    /// @return The supply rate per second (scaled by 1e18)
    function getSupplyRate(uint256 utilization) external view returns (uint64);

    /// @notice Get the current borrow rate per second
    /// @return The borrow rate per second (scaled by 1e18)
    function getBorrowRate(uint256 utilization) external view returns (uint64);

    /// @notice Get current utilization
    /// @return The current utilization (scaled by 1e18)
    function getUtilization() external view returns (uint256);

    /// @notice Seconds per year for rate conversion
    function baseTrackingSupplySpeed() external view returns (uint256);
}

/// @title CompoundV3RateAdapter
/// @author Kairos Protocol
/// @notice Adapter to fetch interest rates from Compound V3 (Comet)
/// @dev Converts Compound's per-second rates to annual rates in WAD
contract CompoundV3RateAdapter is IRateSource {
    /// @notice Compound V3 Comet contract
    IComet public immutable comet;

    /// @notice Seconds per year (used for APY conversion)
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /// @notice WAD precision
    uint256 private constant WAD = 1e18;

    /// @notice Invalid comet address
    error InvalidComet();

    constructor(address _comet) {
        if (_comet == address(0)) revert InvalidComet();
        comet = IComet(_comet);
    }

    /// @notice Get current supply rate in WAD (annualized)
    /// @return rate Supply rate (APY) in WAD precision
    function getSupplyRate() external view override returns (uint256 rate) {
        uint256 utilization = comet.getUtilization();
        uint256 ratePerSecond = comet.getSupplyRate(utilization);
        // Convert per-second rate to annual rate
        // APY = (1 + ratePerSecond)^secondsPerYear - 1
        // Simplified: APY ≈ ratePerSecond * secondsPerYear (for small rates)
        rate = ratePerSecond * SECONDS_PER_YEAR;
    }

    /// @notice Get current borrow rate in WAD (annualized)
    /// @return rate Borrow rate (APY) in WAD precision
    function getBorrowRate() external view override returns (uint256 rate) {
        uint256 utilization = comet.getUtilization();
        uint256 ratePerSecond = comet.getBorrowRate(utilization);
        // Convert per-second rate to annual rate
        rate = ratePerSecond * SECONDS_PER_YEAR;
    }

    /// @notice Get both rates
    /// @return supplyRate Supply rate in WAD (annualized)
    /// @return borrowRate Borrow rate in WAD (annualized)
    function getRates() external view returns (uint256 supplyRate, uint256 borrowRate) {
        uint256 utilization = comet.getUtilization();
        supplyRate = uint256(comet.getSupplyRate(utilization)) * SECONDS_PER_YEAR;
        borrowRate = uint256(comet.getBorrowRate(utilization)) * SECONDS_PER_YEAR;
    }

    /// @notice Get current utilization
    /// @return utilization Current utilization in WAD
    function getUtilization() external view returns (uint256 utilization) {
        utilization = comet.getUtilization();
    }
}
