// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IComet.sol";
import "./interfaces/IRateModel.sol";
import "./interfaces/IPriceOracle.sol";

/// @title CometStorage
/// @notice Storage layout for the Comet lending pool
/// @dev Inheriting contracts should not declare storage variables before this
abstract contract CometStorage {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The scale for rates (1e18 = 100%)
    uint256 internal constant FACTOR_SCALE = 1e18;

    /// @notice Seconds per year for rate calculations
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /// @notice Minimum collateral value to prevent dust attacks
    uint256 internal constant MIN_COLLATERAL_VALUE = 1e6;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The base token (e.g., USDC)
    address public immutable baseToken;

    /// @notice Decimals of the base token
    uint8 public immutable baseTokenDecimals;

    /// @notice The interest rate model
    IRateModel public immutable rateModel;

    /// @notice The reserve factor (portion of interest that goes to reserves)
    uint64 public immutable reserveFactorMantissa;

    /*//////////////////////////////////////////////////////////////
                              STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Total amount of base token supplied
    uint104 internal _totalSupplyBase;

    /// @notice Total amount of base token borrowed
    uint104 internal _totalBorrowBase;

    /// @notice Total reserves accumulated
    uint104 internal _totalReserves;

    /// @notice Last time interest was accrued
    uint64 internal _lastAccrualTime;

    /// @notice Base supply index (for interest accrual)
    uint64 internal _baseSupplyIndex;

    /// @notice Base borrow index (for interest accrual)
    uint64 internal _baseBorrowIndex;

    /// @notice User principal balances
    mapping(address => IComet.UserBasic) internal _userBasic;

    /// @notice User collateral balances: user => asset => amount
    mapping(address => mapping(address => uint128)) internal _userCollateral;

    /// @notice Total collateral for each asset
    mapping(address => uint256) internal _totalCollateral;

    /// @notice Collateral asset configurations
    IComet.AssetConfig[] internal _assetConfigs;

    /// @notice Mapping from asset address to its index in _assetConfigs
    mapping(address => uint8) internal _assetIndex;

    /// @notice Whether the asset is configured as collateral
    mapping(address => bool) internal _isCollateralAsset;

    /// @notice Paused state
    bool public paused;

    /// @notice Governor/admin address
    address public governor;

    /// @notice Price oracle for collateral valuation (FIX C-03)
    IPriceOracle public priceOracle;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address baseToken_,
        uint8 baseTokenDecimals_,
        address rateModel_,
        uint64 reserveFactorMantissa_
    ) {
        baseToken = baseToken_;
        baseTokenDecimals = baseTokenDecimals_;
        rateModel = IRateModel(rateModel_);
        reserveFactorMantissa = reserveFactorMantissa_;

        // Initialize indices to 1e18 (100%)
        _baseSupplyIndex = uint64(FACTOR_SCALE);
        _baseBorrowIndex = uint64(FACTOR_SCALE);
        _lastAccrualTime = uint64(block.timestamp);
    }
}
