// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRateSource.sol";

/// @title ILendingPool (Aave V2 interface used by Lendle)
/// @notice Minimal interface for Lendle's lending pool on Mantle
interface ILendingPool {
    struct ReserveData {
        uint256 configuration;
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint8 id;
    }

    function getReserveData(address asset) external view returns (ReserveData memory);
}

/// @title LendleRateAdapter
/// @author IRS Protocol
/// @notice Adapter to fetch interest rates from Lendle on Mantle
/// @dev Lendle is an Aave V2 fork, rates are in RAY precision (1e27)
contract LendleRateAdapter is IRateSource {
    /// @notice Lendle LendingPool contract on Mantle
    ILendingPool public immutable lendingPool;

    /// @notice Asset to get rates for (USDC)
    address public immutable asset;

    /// @notice RAY precision (1e27)
    uint256 private constant RAY = 1e27;

    /// @notice WAD precision (1e18)
    uint256 private constant WAD = 1e18;

    /// @notice Invalid pool address
    error InvalidPool();

    /// @notice Invalid asset address
    error InvalidAsset();

    /// @notice Lendle LendingPool on Mantle Mainnet
    address public constant LENDLE_POOL_MANTLE = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    /// @notice USDC on Mantle
    address public constant USDC_MANTLE = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;

    constructor(address _pool, address _asset) {
        if (_pool == address(0)) revert InvalidPool();
        if (_asset == address(0)) revert InvalidAsset();

        lendingPool = ILendingPool(_pool);
        asset = _asset;
    }

    /// @notice Get current supply rate in WAD
    /// @return rate Supply rate (APY) in WAD precision
    function getSupplyRate() external view override returns (uint256 rate) {
        ILendingPool.ReserveData memory data = lendingPool.getReserveData(asset);
        // Convert from RAY (1e27) to WAD (1e18)
        rate = uint256(data.currentLiquidityRate) * WAD / RAY;
    }

    /// @notice Get current borrow rate in WAD
    /// @return rate Variable borrow rate (APY) in WAD precision
    function getBorrowRate() external view override returns (uint256 rate) {
        ILendingPool.ReserveData memory data = lendingPool.getReserveData(asset);
        // Convert from RAY (1e27) to WAD (1e18)
        rate = uint256(data.currentVariableBorrowRate) * WAD / RAY;
    }

    /// @notice Get both rates
    /// @return supplyRate Supply rate in WAD
    /// @return borrowRate Borrow rate in WAD
    function getRates() external view returns (uint256 supplyRate, uint256 borrowRate) {
        ILendingPool.ReserveData memory data = lendingPool.getReserveData(asset);
        supplyRate = uint256(data.currentLiquidityRate) * WAD / RAY;
        borrowRate = uint256(data.currentVariableBorrowRate) * WAD / RAY;
    }

    /// @notice Get reserve data timestamp
    /// @return timestamp Last update timestamp
    function getLastUpdateTimestamp() external view returns (uint40 timestamp) {
        ILendingPool.ReserveData memory data = lendingPool.getReserveData(asset);
        timestamp = data.lastUpdateTimestamp;
    }
}
