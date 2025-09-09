// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title IPriceFeed
 * @dev Interface for price feed functionality
 * @notice This interface defines the contract for Chainlink-style price feeds
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
 * @custom:version 1.0.0
 */
interface IPriceFeed {
    /**
     * @dev Returns the latest round data from the price feed
     * @return roundId The round ID
     * @return answer The price answer
     * @return startedAt Timestamp when the round started
     * @return updatedAt Timestamp when the round was updated
     * @return answeredInRound The round ID in which the answer was computed
     * @notice This function provides the most recent price data
     * @custom:security Ensure the price feed is not stale before using the data
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /**
     * @dev Returns the number of decimals used by the price feed
     * @return The number of decimal places
     * @notice This function helps normalize price calculations
     */
    function decimals() external view returns (uint8);
}
