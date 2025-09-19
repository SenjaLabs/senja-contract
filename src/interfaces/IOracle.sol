// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IOracle
 * @dev Interface for price oracle functionality
 * @notice This interface defines the contract for price feeds and token calculations
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IOracle {
    function latestRoundData() external view returns (uint80, uint256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}
