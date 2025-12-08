// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

/**
 * @title TokenDataStream
 * @author Senja Labs
 * @notice Contract that manages price feed mappings for tokens in the lending protocol
 * @dev This contract acts as a registry that maps token addresses to their corresponding
 *      price feed contracts. It provides a unified interface for accessing token price data
 *      from various oracle sources while maintaining Chainlink compatibility.
 *
 * Key Features:
 * - Token to price feed address mapping
 * - Chainlink-compatible price data interface
 * - Owner-controlled price feed configuration
 * - Decimal precision handling for different oracles
 * - Centralized price data access point for the protocol
 */
contract TokenDataStream is Ownable {
    // =============================================================
    //                           ERRORS
    // =============================================================

    /// @notice Thrown when attempting to access price data for a token without a configured price feed
    /// @param token The token address that doesn't have a price feed configured
    error TokenPriceFeedNotSet(address token);

    /// @notice Thrown when the price feed returns a negative price value
    /// @param price The negative price value that was returned
    error NegativePriceAnswer(int256 price);

    /// @notice Thrown when a zero address is provided as a parameter
    error ZeroAddress();

    /// @notice Thrown when the price data is stale (older than 1 hour)
    /// @param token The token address for which the price is stale
    /// @param priceFeed The price feed contract address that returned stale data
    /// @param updatedAt The timestamp when the price was last updated
    error PriceStale(address token, address priceFeed, uint256 updatedAt);

    // =============================================================
    //                       STATE VARIABLES
    // =============================================================

    /// @notice Mapping of token addresses to their corresponding price feed contract addresses
    /// @dev token address => price feed contract address
    mapping(address => address) public tokenPriceFeed;

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @notice Emitted when a token's price feed is configured or updated
    /// @param token The token address that was configured
    /// @param priceFeed The price feed contract address that was set
    event TokenPriceFeedSet(address token, address priceFeed);

    // =============================================================
    //                           CONSTRUCTOR
    // =============================================================

    /// @notice Initializes the TokenDataStream contract
    /// @dev Sets up Ownable with the deployer as the initial owner
    constructor() Ownable(msg.sender) {}

    // =============================================================
    //                   CONFIGURATION FUNCTIONS
    // =============================================================

    /// @notice Sets or updates the price feed contract for a token
    /// @dev Only the contract owner can call this function. Validates that neither the token
    ///      nor the price feed address is zero. Emits TokenPriceFeedSet event on success.
    /// @param _token The token address to configure
    /// @param _priceFeed The price feed contract address for this token
    function setTokenPriceFeed(address _token, address _priceFeed) public onlyOwner {
        if (_token == address(0)) revert ZeroAddress();
        if (_priceFeed == address(0)) revert ZeroAddress();
        tokenPriceFeed[_token] = _priceFeed;
        emit TokenPriceFeedSet(_token, _priceFeed);
    }

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================

    /// @notice Returns the number of decimals used by a token's price feed
    /// @dev Calls the decimals function on the configured price feed contract.
    ///      Reverts if no price feed is configured for the given token.
    /// @param _token The token address to get decimals for
    /// @return The number of decimals used by the token's price feed
    function decimals(address _token) public view returns (uint256) {
        if (tokenPriceFeed[_token] == address(0)) revert TokenPriceFeedNotSet(_token);
        return IPriceFeed(tokenPriceFeed[_token]).decimals();
    }

    /// @notice Returns the latest price data for a token in Chainlink-compatible format
    /// @dev Retrieves price data from the configured price feed and converts int256 price to uint256.
    ///      Validates that:
    ///      - A price feed is configured for the token
    ///      - The price data is not stale (updated within the last hour)
    ///      - The price is not negative
    ///      Note: startedAt and answeredInRound are returned as 0 for compatibility
    /// @param _token The token address to get price data for
    /// @return roundId The round ID from the price feed
    /// @return price The price value (converted from int256 to uint256)
    /// @return startedAt Timestamp when the round started (always returns 0)
    /// @return updatedAt Timestamp when the price was last updated
    /// @return answeredInRound The round when this answer was computed (always returns 0)
    function latestRoundData(address _token) public view returns (uint80, uint256, uint256, uint256, uint80) {
        if (tokenPriceFeed[_token] == address(0)) revert TokenPriceFeedNotSet(_token);
        address _priceFeed = tokenPriceFeed[_token];
        (uint80 idRound, int256 priceAnswer, uint256 updatedAt) = IPriceFeed(_priceFeed).latestRoundData();
        if (block.timestamp - updatedAt > 3600) revert PriceStale(_token, _priceFeed, updatedAt);
        if (priceAnswer < 0) revert NegativePriceAnswer(priceAnswer);

        // forge-lint: disable-next-line(unsafe-typecast)
        return (idRound, uint256(priceAnswer), 0, updatedAt, 0);
    }
}
