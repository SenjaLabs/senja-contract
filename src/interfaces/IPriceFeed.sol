// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IPriceFeed
 * @dev Interface for price feed functionality
 * @notice This interface defines the contract for Chainlink-style price feeds
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IPriceFeed {
    /**
     * @dev Returns the latest round data from the price feed
     * @return roundId The round ID
     * @return priceAnswer The price value
     * @return updatedAt Timestamp when the price was last updated
     * @notice This function provides the most recent price data
     * @custom:security Ensure the price feed is not stale before using the data
     */
    function latestRoundData() external view returns (uint80 roundId, int256 priceAnswer, uint256 updatedAt);

    /**
     * @dev Returns the number of decimals used by the price feed
     * @return The number of decimal places
     * @notice This function helps normalize price calculations
     */
    function decimals() external view returns (uint8);
}
