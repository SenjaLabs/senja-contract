// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITokenDataStream
 * @author Senja Labs
 * @notice Interface for the TokenDataStream contract that manages price feeds for tokens
 * @dev This interface defines functions for managing token price feeds and streaming status
 */
interface ITokenDataStream {
    /// @notice Returns the price feed contract address for a token
    /// @param _token The token address to get the price feed for
    /// @return The price feed contract address
    function tokenPriceFeed(address _token) external view returns (address);

    /// @notice Sets the price feed contract address for a token
    /// @param _token The token address to configure
    /// @param _priceFeed The price feed contract address
    function setTokenPriceFeed(address _token, address _priceFeed) external;

    /// @notice Returns the number of decimals for a token's price feed
    /// @param _token The token address to query
    /// @return The number of decimals used by the price feed
    function decimals(address _token) external view returns (uint256);

    /// @notice Returns the latest price data for a token in Chainlink format
    /// @param _token The token address to get price data for
    /// @return roundId The round ID
    /// @return price The price value
    /// @return startedAt When the round started
    /// @return updatedAt When the price was last updated
    /// @return answeredInRound The round when this answer was computed
    function latestRoundData(address _token) external view returns (uint80, uint256, uint256, uint256, uint80);
}
