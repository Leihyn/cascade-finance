// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";

/// @title IAaveV3Pool
/// @notice Minimal interface for Aave V3 Pool
interface IAaveV3Pool {
    struct ReserveData {
        //stores the reserve configuration
        uint256 configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    function getReserveData(address asset) external view returns (ReserveData memory);
}

/// @title AaveV3RateAdapter
/// @author Kairos Protocol
/// @notice Adapter to fetch interest rates from Aave V3
/// @dev Converts Aave's RAY precision (1e27) to WAD precision (1e18)
contract AaveV3RateAdapter is IRateSource {
    /// @notice Aave V3 Pool contract
    IAaveV3Pool public immutable pool;

    /// @notice Asset to get rates for (e.g., USDC)
    address public immutable asset;

    /// @notice RAY precision (1e27)
    uint256 private constant RAY = 1e27;

    /// @notice WAD precision (1e18)
    uint256 private constant WAD = 1e18;

    /// @notice Emitted when rate is fetched
    event RateFetched(uint256 supplyRate, uint256 borrowRate, uint256 timestamp);

    /// @notice Invalid pool address
    error InvalidPool();

    /// @notice Invalid asset address
    error InvalidAsset();

    constructor(address _pool, address _asset) {
        if (_pool == address(0)) revert InvalidPool();
        if (_asset == address(0)) revert InvalidAsset();

        pool = IAaveV3Pool(_pool);
        asset = _asset;
    }

    /// @notice Get current supply rate in WAD
    /// @return rate Supply rate (APY) in WAD precision
    function getSupplyRate() external view override returns (uint256 rate) {
        IAaveV3Pool.ReserveData memory data = pool.getReserveData(asset);
        // Convert from RAY (1e27) to WAD (1e18)
        rate = uint256(data.currentLiquidityRate) * WAD / RAY;
    }

    /// @notice Get current borrow rate in WAD
    /// @return rate Variable borrow rate (APY) in WAD precision
    function getBorrowRate() external view override returns (uint256 rate) {
        IAaveV3Pool.ReserveData memory data = pool.getReserveData(asset);
        // Convert from RAY (1e27) to WAD (1e18)
        rate = uint256(data.currentVariableBorrowRate) * WAD / RAY;
    }

    /// @notice Get both rates
    /// @return supplyRate Supply rate in WAD
    /// @return borrowRate Borrow rate in WAD
    function getRates() external view returns (uint256 supplyRate, uint256 borrowRate) {
        IAaveV3Pool.ReserveData memory data = pool.getReserveData(asset);
        supplyRate = uint256(data.currentLiquidityRate) * WAD / RAY;
        borrowRate = uint256(data.currentVariableBorrowRate) * WAD / RAY;
    }

    /// @notice Get reserve data timestamp
    /// @return timestamp Last update timestamp
    function getLastUpdateTimestamp() external view returns (uint40 timestamp) {
        IAaveV3Pool.ReserveData memory data = pool.getReserveData(asset);
        timestamp = data.lastUpdateTimestamp;
    }
}
