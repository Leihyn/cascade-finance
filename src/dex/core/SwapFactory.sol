// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SwapPair.sol";
import "../interfaces/ISwapFactory.sol";

/// @title SwapFactory
/// @notice Factory for creating DEX trading pairs
/// @dev Based on Uniswap V2 Factory pattern
contract SwapFactory is ISwapFactory {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address feeToSetter_) {
        feeToSetter = feeToSetter_;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /*//////////////////////////////////////////////////////////////
                          FACTORY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "SwapFactory: IDENTICAL_ADDRESSES");

        // Sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "SwapFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "SwapFactory: PAIR_EXISTS");

        // Create pair using CREATE2 for deterministic addresses
        bytes memory bytecode = type(SwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // Initialize pair
        SwapPair(pair).initialize(token0, token1);

        // Store mapping both ways
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFeeTo(address newFeeTo) external {
        require(msg.sender == feeToSetter, "SwapFactory: FORBIDDEN");
        feeTo = newFeeTo;
    }

    function setFeeToSetter(address newFeeToSetter) external {
        require(msg.sender == feeToSetter, "SwapFactory: FORBIDDEN");
        feeToSetter = newFeeToSetter;
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Compute the pair address without deploying
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return pair The computed pair address
    function pairFor(address tokenA, address tokenB) external view returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex"ff",
            address(this),
            keccak256(abi.encodePacked(token0, token1)),
            keccak256(type(SwapPair).creationCode)
        )))));
    }
}
