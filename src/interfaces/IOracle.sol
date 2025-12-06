// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IOracle
 * @notice Interface for price oracle functionality
 * @dev Defines the contract for price feeds and token calculations
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IOracle {
    /**
     * @notice Returns the latest price data from the oracle
     * @return roundId The round ID
     * @return answer The price value
     * @return startedAt Timestamp when the round started
     * @return updatedAt Timestamp when the price was last updated
     * @return answeredInRound The round when this answer was computed
     */
    function latestRoundData() external view returns (uint80, uint256, uint256, uint256, uint80);

    /**
     * @notice Returns the number of decimals used by the oracle
     * @return The number of decimal places
     */
    function decimals() external view returns (uint8);
}
