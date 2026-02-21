// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IComet
/// @notice Interface for the Comet lending pool (Compound V3 style)
/// @dev Single-asset lending pool with collateral support
interface IComet {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice User's principal balance (positive = supply, negative = borrow)
    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
    }

    /// @notice Collateral asset configuration
    struct AssetConfig {
        address asset;
        address priceFeed;
        uint64 borrowCollateralFactor;  // Scaled by 1e18
        uint64 liquidateCollateralFactor;  // Scaled by 1e18
        uint64 liquidationFactor;  // Scaled by 1e18
        uint128 supplyCap;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Supply(address indexed from, address indexed dst, uint256 amount);
    event Withdraw(address indexed src, address indexed to, uint256 amount);
    event SupplyCollateral(address indexed from, address indexed dst, address indexed asset, uint256 amount);
    event WithdrawCollateral(address indexed src, address indexed to, address indexed asset, uint256 amount);
    event Absorb(address indexed absorber, address indexed borrower, uint256 basePaidOut, uint256 usdValue);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply base asset to the protocol
    /// @param asset The asset to supply (must be base asset)
    /// @param amount The amount to supply
    function supply(address asset, uint256 amount) external;

    /// @notice Supply base asset to a specific account
    /// @param dst The destination account
    /// @param asset The asset to supply
    /// @param amount The amount to supply
    function supplyTo(address dst, address asset, uint256 amount) external;

    /// @notice Withdraw base asset from the protocol
    /// @param asset The asset to withdraw
    /// @param amount The amount to withdraw
    function withdraw(address asset, uint256 amount) external;

    /// @notice Withdraw base asset to a specific account
    /// @param to The destination account
    /// @param asset The asset to withdraw
    /// @param amount The amount to withdraw
    function withdrawTo(address to, address asset, uint256 amount) external;

    /// @notice Supply collateral asset
    /// @param asset The collateral asset to supply
    /// @param amount The amount to supply
    function supplyCollateral(address asset, uint256 amount) external;

    /// @notice Withdraw collateral asset
    /// @param asset The collateral asset to withdraw
    /// @param amount The amount to withdraw
    function withdrawCollateral(address asset, uint256 amount) external;

    /// @notice Absorb an underwater account (liquidation)
    /// @param absorber The account receiving the liquidation bonus
    /// @param accounts The accounts to absorb
    function absorb(address absorber, address[] calldata accounts) external;

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Note: baseToken() and baseTokenDecimals() are implemented via public state variables

    /// @notice Get the total supply of base asset
    function totalSupply() external view returns (uint256);

    /// @notice Get the total borrow of base asset
    function totalBorrow() external view returns (uint256);

    /// @notice Get user's principal balance
    /// @param account The account to query
    /// @return The principal balance (positive = supply, negative = borrow)
    function userBasic(address account) external view returns (UserBasic memory);

    /// @notice Get user's collateral balance for an asset
    /// @param account The account to query
    /// @param asset The collateral asset
    /// @return The collateral balance
    function userCollateral(address account, address asset) external view returns (uint128);

    /// @notice Get the current supply rate per second
    /// @return The supply rate scaled by 1e18
    function getSupplyRate() external view returns (uint64);

    /// @notice Get the current borrow rate per second
    /// @return The borrow rate scaled by 1e18
    function getBorrowRate() external view returns (uint64);

    /// @notice Get the current utilization rate
    /// @return The utilization rate scaled by 1e18
    function getUtilization() external view returns (uint256);

    /// @notice Check if an account is liquidatable
    /// @param account The account to check
    /// @return True if the account can be liquidated
    function isLiquidatable(address account) external view returns (bool);

    /// @notice Get the borrow balance for an account
    /// @param account The account to query
    /// @return The borrow balance including accrued interest
    function borrowBalanceOf(address account) external view returns (uint256);

    /// @notice Get the supply balance for an account
    /// @param account The account to query
    /// @return The supply balance including accrued interest
    function balanceOf(address account) external view returns (uint256);

    /// @notice Accrue interest
    function accrueInterest() external;

    /// @notice Get number of collateral assets
    function numAssets() external view returns (uint8);

    /// @notice Get collateral asset config by index
    function getAssetInfo(uint8 i) external view returns (AssetConfig memory);
}
