// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Orakl
 * @author Senja Labs
 * @notice Mock price feed contract that simulates Chainlink-style price feed functionality for testing purposes
 * @dev This contract provides a simple price oracle that mimics the Chainlink AggregatorV3Interface.
 *      It allows the owner to manually set prices and maintains round data compatible with Chainlink's format.
 *      This is intended for testing and development environments only, not for production use.
 * @custom:version 1.0.0
 * @custom:security-contact security@senja.finance
 */
contract Orakl is Ownable {
    // ============ State Variables ============

    /// @notice Address of the token this price feed tracks
    /// @dev This is set during contract deployment and remains immutable
    address public token;

    /// @notice Current round ID for the price feed
    /// @dev Increments with each price update to track different price rounds
    uint80 public roundId;

    /// @notice Current price of the token
    /// @dev Price is stored with the precision defined by the decimals variable (default 8 decimals)
    int256 public price;

    /// @notice Timestamp when the price was last updated
    /// @dev This is set to block.timestamp when setPrice is called
    uint256 public updatedAt;

    /// @notice Number of decimal places for the price
    /// @dev Default is 8 decimals to match standard Chainlink USD price feeds
    uint8 public decimals = 8;

    // ============ Constructor ============

    /**
     * @notice Initializes the price feed with the specified token address
     * @dev Sets the msg.sender as the initial owner via Ownable constructor
     * @param _token Address of the token to track prices for
     */
    constructor(address _token) Ownable(msg.sender) {
        token = _token;
    }

    // ============ External Functions ============

    /**
     * @notice Updates the token price to a new value
     * @dev Sets all round data including roundId, price, timestamps, and answeredInRound.
     *      Currently sets roundId to 1 on every update, which could be improved to increment.
     * @param _price The new price to set, denominated in the precision of the decimals variable
     * @custom:security Only callable by the contract owner
     * @custom:emits Could emit a PriceUpdated event if implemented
     */
    function setPrice(int256 _price) public onlyOwner {
        roundId = 1;
        price = _price;
        updatedAt = block.timestamp;
    }

    /**
     * @notice Returns the latest round data in Chainlink AggregatorV3Interface format
     * @dev This function mimics Chainlink's latestRoundData interface for compatibility with existing integrations
     * @return roundId_ The current round ID
     * @return answer_ The current price of the token
     * @return updatedAt_ Timestamp when the price was last updated
     */
    function latestRoundData() public view returns (uint80, int256, uint256) {
        return (roundId, price, updatedAt);
    }
}
