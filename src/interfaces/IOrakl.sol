// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IOrakl
 * @notice Interface for Orakl Network price oracle
 * @dev Defines functions for accessing price feed data from Orakl Network on Klaytn/KAIA
 */
interface IOrakl {
    /**
     * @notice Returns the latest price data from Orakl Network
     * @return roundId The round ID
     * @return answer The price value (can be negative)
     * @return updatedAt Timestamp when the price was last updated
     */
    function latestRoundData() external view returns (uint80, int256, uint256);

    /**
     * @notice Returns the number of decimals used by the price feed
     * @return The number of decimal places
     */
    function decimals() external view returns (uint8);
}
