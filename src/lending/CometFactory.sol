// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Comet.sol";
import "./models/JumpRateModel.sol";

/// @title CometFactory
/// @notice Factory for deploying new Comet lending markets
/// @dev Simplifies deployment of lending pools with proper configuration
contract CometFactory {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketCreated(
        address indexed comet,
        address indexed baseToken,
        address indexed rateModel,
        string name
    );

    event RateModelCreated(
        address indexed rateModel,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    );

    /*//////////////////////////////////////////////////////////////
                              STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice All deployed markets
    address[] public allMarkets;

    /// @notice Mapping from base token to market
    mapping(address => address) public getMarket;

    /// @notice All deployed rate models
    address[] public allRateModels;

    /// @notice Default governor for new markets
    address public defaultGovernor;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address defaultGovernor_) {
        require(defaultGovernor_ != address(0), "Zero address");
        defaultGovernor = defaultGovernor_;
    }

    /*//////////////////////////////////////////////////////////////
                          FACTORY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new interest rate model
    /// @param baseRatePerYear The base interest rate per year (scaled by 1e18)
    /// @param multiplierPerYear The multiplier for utilization below kink (scaled by 1e18)
    /// @param jumpMultiplierPerYear The multiplier for utilization above kink (scaled by 1e18)
    /// @param kink The utilization threshold (scaled by 1e18)
    /// @return rateModel The address of the deployed rate model
    function createRateModel(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    ) external returns (address rateModel) {
        rateModel = address(
            new JumpRateModel(
                baseRatePerYear,
                multiplierPerYear,
                jumpMultiplierPerYear,
                kink
            )
        );

        allRateModels.push(rateModel);

        emit RateModelCreated(
            rateModel,
            baseRatePerYear,
            multiplierPerYear,
            jumpMultiplierPerYear,
            kink
        );
    }

    /// @notice Create a new Comet lending market
    /// @param baseToken The base token for the market (e.g., USDC)
    /// @param baseTokenDecimals Decimals of the base token
    /// @param rateModel Address of the interest rate model
    /// @param reserveFactorMantissa Reserve factor (scaled by 1e18)
    /// @param name Human-readable market name
    /// @return comet The address of the deployed market
    function createMarket(
        address baseToken,
        uint8 baseTokenDecimals,
        address rateModel,
        uint64 reserveFactorMantissa,
        string calldata name
    ) external returns (address comet) {
        require(baseToken != address(0), "Zero base token");
        require(rateModel != address(0), "Zero rate model");
        require(getMarket[baseToken] == address(0), "Market exists");

        comet = address(
            new Comet(
                baseToken,
                baseTokenDecimals,
                rateModel,
                reserveFactorMantissa,
                defaultGovernor
            )
        );

        allMarkets.push(comet);
        getMarket[baseToken] = comet;

        emit MarketCreated(comet, baseToken, rateModel, name);
    }

    /// @notice Create a market with a new rate model in one transaction
    /// @param baseToken The base token for the market
    /// @param baseTokenDecimals Decimals of the base token
    /// @param baseRatePerYear Base interest rate per year
    /// @param multiplierPerYear Multiplier for utilization below kink
    /// @param jumpMultiplierPerYear Multiplier for utilization above kink
    /// @param kink Utilization threshold
    /// @param reserveFactorMantissa Reserve factor
    /// @param name Market name
    /// @return comet The address of the deployed market
    /// @return rateModel The address of the deployed rate model
    function createMarketWithRateModel(
        address baseToken,
        uint8 baseTokenDecimals,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink,
        uint64 reserveFactorMantissa,
        string calldata name
    ) external returns (address comet, address rateModel) {
        // Create rate model first
        rateModel = address(
            new JumpRateModel(
                baseRatePerYear,
                multiplierPerYear,
                jumpMultiplierPerYear,
                kink
            )
        );
        allRateModels.push(rateModel);

        emit RateModelCreated(
            rateModel,
            baseRatePerYear,
            multiplierPerYear,
            jumpMultiplierPerYear,
            kink
        );

        // Create market
        require(baseToken != address(0), "Zero base token");
        require(getMarket[baseToken] == address(0), "Market exists");

        comet = address(
            new Comet(
                baseToken,
                baseTokenDecimals,
                rateModel,
                reserveFactorMantissa,
                defaultGovernor
            )
        );

        allMarkets.push(comet);
        getMarket[baseToken] = comet;

        emit MarketCreated(comet, baseToken, rateModel, name);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the number of deployed markets
    function allMarketsLength() external view returns (uint256) {
        return allMarkets.length;
    }

    /// @notice Get the number of deployed rate models
    function allRateModelsLength() external view returns (uint256) {
        return allRateModels.length;
    }

    /// @notice Update the default governor for new markets
    function setDefaultGovernor(address newGovernor) external {
        require(msg.sender == defaultGovernor, "Unauthorized");
        require(newGovernor != address(0), "Zero address");
        defaultGovernor = newGovernor;
    }
}
