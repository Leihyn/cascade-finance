// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "../lending/interfaces/IPriceOracle.sol";

/// @notice Chainlink Aggregator V3 Interface
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title ChainlinkPriceOracle
/// @notice Price oracle using Chainlink price feeds
/// @dev Aggregates prices from Chainlink and normalizes to 18 decimals
contract ChainlinkPriceOracle is IPriceOracle, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PriceFeed {
        AggregatorV3Interface feed;
        uint8 decimals;
        uint256 heartbeat;  // Maximum acceptable age in seconds
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Price feed configuration for each asset
    mapping(address => PriceFeed) public priceFeeds;

    /// @notice Fallback prices for emergencies (admin-set)
    mapping(address => uint256) public fallbackPrices;

    /// @notice Whether fallback mode is enabled for an asset
    mapping(address => bool) public fallbackEnabled;

    /// @notice Maximum price staleness before considering invalid
    uint256 public constant MAX_STALENESS = 24 hours;

    /// @notice Price precision (18 decimals)
    uint256 public constant PRICE_PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PriceFeedSet(address indexed asset, address indexed feed, uint256 heartbeat);
    event FallbackPriceSet(address indexed asset, uint256 price);
    event FallbackModeChanged(address indexed asset, bool enabled);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price of an asset in USD (18 decimals)
    /// @param asset The asset address
    /// @return price The price in USD with 18 decimals
    function getPrice(address asset) external view override returns (uint256 price) {
        // Check fallback first
        if (fallbackEnabled[asset]) {
            return fallbackPrices[asset];
        }

        PriceFeed storage priceFeed = priceFeeds[asset];
        require(priceFeed.isActive, "ChainlinkOracle: no price feed");

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.feed.latestRoundData();

        // Validate the price data
        require(answer > 0, "ChainlinkOracle: invalid price");
        require(updatedAt > 0, "ChainlinkOracle: round not complete");
        require(answeredInRound >= roundId, "ChainlinkOracle: stale price");
        require(
            block.timestamp - updatedAt <= priceFeed.heartbeat,
            "ChainlinkOracle: price too old"
        );

        // Normalize to 18 decimals
        price = uint256(answer) * PRICE_PRECISION / (10 ** priceFeed.decimals);
    }

    /// @notice Get price with timestamp for staleness validation
    /// @dev Phase 1 Security: Required by IPriceOracle interface for Comet
    /// @param asset The asset address
    /// @return price The price in USD with 18 decimals
    /// @return updatedAt The timestamp of the last update
    function getPriceWithTimestamp(address asset) external view override returns (uint256 price, uint256 updatedAt) {
        if (fallbackEnabled[asset]) {
            return (fallbackPrices[asset], block.timestamp);
        }

        PriceFeed storage priceFeed = priceFeeds[asset];
        require(priceFeed.isActive, "ChainlinkOracle: no price feed");

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 _updatedAt,
            uint80 answeredInRound
        ) = priceFeed.feed.latestRoundData();

        // Validate the price data
        require(answer > 0, "ChainlinkOracle: invalid price");
        require(_updatedAt > 0, "ChainlinkOracle: round not complete");
        require(answeredInRound >= roundId, "ChainlinkOracle: stale price");

        price = uint256(answer) * PRICE_PRECISION / (10 ** priceFeed.decimals);
        updatedAt = _updatedAt;
    }

    /// @notice Check if a price is valid and fresh
    /// @param asset The asset address
    /// @return valid Whether the price is valid
    function isPriceValid(address asset) external view override returns (bool valid) {
        if (fallbackEnabled[asset]) {
            return fallbackPrices[asset] > 0;
        }

        PriceFeed storage priceFeed = priceFeeds[asset];
        if (!priceFeed.isActive) {
            return false;
        }

        try priceFeed.feed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (answer <= 0) return false;
            if (updatedAt == 0) return false;
            if (answeredInRound < roundId) return false;
            if (block.timestamp - updatedAt > priceFeed.heartbeat) return false;
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Get price with additional metadata
    /// @param asset The asset address
    /// @return price The price in USD with 18 decimals
    /// @return updatedAt The timestamp of the last update
    /// @return isFallback Whether this is a fallback price
    function getPriceWithMetadata(address asset)
        external
        view
        returns (uint256 price, uint256 updatedAt, bool isFallback)
    {
        if (fallbackEnabled[asset]) {
            return (fallbackPrices[asset], block.timestamp, true);
        }

        PriceFeed storage priceFeed = priceFeeds[asset];
        require(priceFeed.isActive, "ChainlinkOracle: no price feed");

        (
            ,
            int256 answer,
            ,
            uint256 _updatedAt,
        ) = priceFeed.feed.latestRoundData();

        price = uint256(answer) * PRICE_PRECISION / (10 ** priceFeed.decimals);
        updatedAt = _updatedAt;
        isFallback = false;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the Chainlink price feed for an asset
    /// @param asset The asset address
    /// @param feed The Chainlink aggregator address
    /// @param heartbeat Maximum acceptable price age in seconds
    function setPriceFeed(
        address asset,
        address feed,
        uint256 heartbeat
    ) external onlyOwner {
        require(feed != address(0), "ChainlinkOracle: invalid feed");
        require(heartbeat > 0 && heartbeat <= MAX_STALENESS, "ChainlinkOracle: invalid heartbeat");

        AggregatorV3Interface aggregator = AggregatorV3Interface(feed);
        uint8 decimals = aggregator.decimals();

        priceFeeds[asset] = PriceFeed({
            feed: aggregator,
            decimals: decimals,
            heartbeat: heartbeat,
            isActive: true
        });

        emit PriceFeedSet(asset, feed, heartbeat);
    }

    /// @notice Remove a price feed
    /// @param asset The asset address
    function removePriceFeed(address asset) external onlyOwner {
        delete priceFeeds[asset];
        emit PriceFeedSet(asset, address(0), 0);
    }

    /// @notice Set a fallback price for emergencies
    /// @param asset The asset address
    /// @param price The fallback price (18 decimals)
    function setFallbackPrice(address asset, uint256 price) external onlyOwner {
        fallbackPrices[asset] = price;
        emit FallbackPriceSet(asset, price);
    }

    /// @notice Enable or disable fallback mode for an asset
    /// @param asset The asset address
    /// @param enabled Whether to enable fallback mode
    function setFallbackMode(address asset, bool enabled) external onlyOwner {
        fallbackEnabled[asset] = enabled;
        emit FallbackModeChanged(asset, enabled);
    }

    /// @notice Batch set price feeds
    /// @param assets Array of asset addresses
    /// @param feeds Array of Chainlink aggregator addresses
    /// @param heartbeats Array of heartbeat values
    function batchSetPriceFeeds(
        address[] calldata assets,
        address[] calldata feeds,
        uint256[] calldata heartbeats
    ) external onlyOwner {
        require(
            assets.length == feeds.length && feeds.length == heartbeats.length,
            "ChainlinkOracle: length mismatch"
        );

        for (uint256 i = 0; i < assets.length; i++) {
            AggregatorV3Interface aggregator = AggregatorV3Interface(feeds[i]);
            uint8 decimals = aggregator.decimals();

            priceFeeds[assets[i]] = PriceFeed({
                feed: aggregator,
                decimals: decimals,
                heartbeat: heartbeats[i],
                isActive: true
            });

            emit PriceFeedSet(assets[i], feeds[i], heartbeats[i]);
        }
    }
}
