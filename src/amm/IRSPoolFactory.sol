// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRSPool} from "./IRSPool.sol";

/// @title IRSPoolFactory
/// @notice Factory contract for deploying IRS AMM pools
/// @dev Creates pools for different maturities and rate sources
contract IRSPoolFactory is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PoolInfo {
        address pool;
        address collateralToken;
        uint256 maturityDays;
        string rateSource;
        uint256 createdAt;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice All deployed pools
    address[] public allPools;

    /// @notice Pool info by address
    mapping(address => PoolInfo) public poolInfo;

    /// @notice Pools by maturity
    mapping(uint256 => address[]) public poolsByMaturity;

    /// @notice Pools by collateral token
    mapping(address => address[]) public poolsByCollateral;

    /// @notice Fee recipient for all pools
    address public feeRecipient;

    /// @notice Default initial rate (5%)
    uint256 public defaultInitialRate = 0.05e18;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolCreated(
        address indexed pool,
        address indexed collateralToken,
        uint256 maturityDays,
        string rateSource,
        uint256 initialRate
    );

    event PoolDeactivated(address indexed pool);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                           FACTORY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new IRS pool
    /// @param collateralToken The collateral token address
    /// @param decimals Token decimals
    /// @param maturityDays Pool maturity in days
    /// @param rateSource Description of the rate source (e.g., "Aave USDC", "Compound ETH")
    /// @param initialRate The initial target rate
    /// @return pool The deployed pool address
    function createPool(
        address collateralToken,
        uint8 decimals,
        uint256 maturityDays,
        string memory rateSource,
        uint256 initialRate
    ) external onlyOwner returns (address pool) {
        require(collateralToken != address(0), "Factory: invalid collateral");
        require(maturityDays > 0, "Factory: invalid maturity");

        // Deploy new pool
        IRSPool newPool = new IRSPool(
            collateralToken,
            decimals,
            feeRecipient,
            initialRate
        );

        pool = address(newPool);

        // Store pool info
        poolInfo[pool] = PoolInfo({
            pool: pool,
            collateralToken: collateralToken,
            maturityDays: maturityDays,
            rateSource: rateSource,
            createdAt: block.timestamp,
            isActive: true
        });

        allPools.push(pool);
        poolsByMaturity[maturityDays].push(pool);
        poolsByCollateral[collateralToken].push(pool);

        emit PoolCreated(pool, collateralToken, maturityDays, rateSource, initialRate);
    }

    /// @notice Create multiple pools at once
    /// @param collateralTokens Array of collateral token addresses
    /// @param decimalsList Array of token decimals
    /// @param maturityDaysList Array of maturities
    /// @param rateSources Array of rate source descriptions
    /// @param initialRates Array of initial rates
    function batchCreatePools(
        address[] calldata collateralTokens,
        uint8[] calldata decimalsList,
        uint256[] calldata maturityDaysList,
        string[] calldata rateSources,
        uint256[] calldata initialRates
    ) external onlyOwner {
        require(
            collateralTokens.length == decimalsList.length &&
            collateralTokens.length == maturityDaysList.length &&
            collateralTokens.length == rateSources.length &&
            collateralTokens.length == initialRates.length,
            "Factory: length mismatch"
        );

        for (uint256 i = 0; i < collateralTokens.length; i++) {
            IRSPool newPool = new IRSPool(
                collateralTokens[i],
                decimalsList[i],
                feeRecipient,
                initialRates[i]
            );

            address pool = address(newPool);

            poolInfo[pool] = PoolInfo({
                pool: pool,
                collateralToken: collateralTokens[i],
                maturityDays: maturityDaysList[i],
                rateSource: rateSources[i],
                createdAt: block.timestamp,
                isActive: true
            });

            allPools.push(pool);
            poolsByMaturity[maturityDaysList[i]].push(pool);
            poolsByCollateral[collateralTokens[i]].push(pool);

            emit PoolCreated(
                pool,
                collateralTokens[i],
                maturityDaysList[i],
                rateSources[i],
                initialRates[i]
            );
        }
    }

    /// @notice Deactivate a pool
    /// @param pool The pool address
    function deactivatePool(address pool) external onlyOwner {
        require(poolInfo[pool].isActive, "Factory: pool not active");
        poolInfo[pool].isActive = false;
        emit PoolDeactivated(pool);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get total number of pools
    function totalPools() external view returns (uint256) {
        return allPools.length;
    }

    /// @notice Get all pools
    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }

    /// @notice Get active pools only
    function getActivePools() external view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            if (poolInfo[allPools[i]].isActive) {
                activeCount++;
            }
        }

        address[] memory activePools = new address[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            if (poolInfo[allPools[i]].isActive) {
                activePools[index++] = allPools[i];
            }
        }

        return activePools;
    }

    /// @notice Get pools by maturity
    function getPoolsByMaturity(uint256 maturityDays) external view returns (address[] memory) {
        return poolsByMaturity[maturityDays];
    }

    /// @notice Get pools by collateral token
    function getPoolsByCollateral(address collateralToken) external view returns (address[] memory) {
        return poolsByCollateral[collateralToken];
    }

    /// @notice Get pool details
    function getPoolInfo(address pool)
        external
        view
        returns (
            address collateralToken,
            uint256 maturityDays,
            string memory rateSource,
            uint256 createdAt,
            bool isActive
        )
    {
        PoolInfo storage info = poolInfo[pool];
        return (
            info.collateralToken,
            info.maturityDays,
            info.rateSource,
            info.createdAt,
            info.isActive
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update fee recipient for all future pools
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        emit FeeRecipientChanged(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    /// @notice Update default initial rate
    function setDefaultInitialRate(uint256 _rate) external onlyOwner {
        defaultInitialRate = _rate;
    }

    /// @notice Update pool target rate
    function updatePoolRate(address pool, uint256 newRate) external onlyOwner {
        require(poolInfo[pool].pool != address(0), "Factory: pool not found");
        IRSPool(pool).setTargetRate(newRate);
    }

    /// @notice Batch update pool rates
    function batchUpdatePoolRates(
        address[] calldata pools,
        uint256[] calldata newRates
    ) external onlyOwner {
        require(pools.length == newRates.length, "Factory: length mismatch");
        for (uint256 i = 0; i < pools.length; i++) {
            IRSPool(pools[i]).setTargetRate(newRates[i]);
        }
    }
}
