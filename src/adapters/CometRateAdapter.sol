// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";
import "../lending/interfaces/IComet.sol";

/// @title CometRateAdapter
/// @notice Adapter that connects Comet lending pool rates to the IRS protocol
/// @dev Converts per-second rates to annualized WAD rates for IRS oracle
contract CometRateAdapter is IRateSource {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Seconds per year for rate annualization
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice WAD scale (1e18 = 100%)
    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Comet lending pool to read rates from
    IComet public immutable comet;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param comet_ Address of the Comet lending pool
    constructor(address comet_) {
        require(comet_ != address(0), "CometRateAdapter: zero address");
        comet = IComet(comet_);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRateSource
    /// @notice Returns the annualized supply rate from Comet
    /// @return rate Annual supply rate in WAD (1e18 = 100%)
    function getSupplyRate() external view override returns (uint256 rate) {
        // Comet returns per-second rate, we need to annualize
        uint64 perSecondRate = comet.getSupplyRate();
        rate = uint256(perSecondRate) * SECONDS_PER_YEAR;
    }

    /// @inheritdoc IRateSource
    /// @notice Returns the annualized borrow rate from Comet
    /// @return rate Annual borrow rate in WAD (1e18 = 100%)
    function getBorrowRate() external view override returns (uint256 rate) {
        // Comet returns per-second rate, we need to annualize
        uint64 perSecondRate = comet.getBorrowRate();
        rate = uint256(perSecondRate) * SECONDS_PER_YEAR;
    }

    /*//////////////////////////////////////////////////////////////
                        ADDITIONAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current utilization rate from Comet
    /// @return The utilization rate in WAD (1e18 = 100%)
    function getUtilization() external view returns (uint256) {
        return comet.getUtilization();
    }

    /// @notice Get both rates in a single call
    /// @return supplyRate Annual supply rate in WAD
    /// @return borrowRate Annual borrow rate in WAD
    function getRates() external view returns (uint256 supplyRate, uint256 borrowRate) {
        supplyRate = uint256(comet.getSupplyRate()) * SECONDS_PER_YEAR;
        borrowRate = uint256(comet.getBorrowRate()) * SECONDS_PER_YEAR;
    }

    /// @notice Check if the rate source is healthy (non-zero rates when there are borrows)
    /// @return True if rates are valid
    function isHealthy() external view returns (bool) {
        try comet.getSupplyRate() returns (uint64) {
            try comet.getBorrowRate() returns (uint64) {
                return true;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }
}
