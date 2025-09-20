// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Pricefeed
 * @dev Mock price feed contract for testing purposes
 * @notice This contract simulates Chainlink-style price feed functionality
 * @author Senja Team
 * @custom:version 1.0.0
 */
contract Pricefeed is Ownable {
    // ============ State Variables ============

    /**
     * @dev Address of the token this price feed tracks
     */
    address public token;

    /**
     * @dev Current round ID for the price feed
     */
    uint80 public roundId;

    /**
     * @dev Current price of the token
     */
    uint256 public price;

    /**
     * @dev Timestamp when the current round started
     */
    uint256 public startedAt;

    /**
     * @dev Timestamp when the price was last updated
     */
    uint256 public updatedAt;

    /**
     * @dev Round ID in which the answer was computed
     */
    uint80 public answeredInRound;

    /**
     * @dev Number of decimal places for the price
     */
    uint8 public decimals = 8;

    /**
     * @dev Constructor for the Pricefeed contract
     * @param _token Address of the token to track
     * @notice Initializes the price feed with the specified token
     */
    constructor(address _token) Ownable(msg.sender) {
        token = _token;
    }

    /**
     * @dev Sets the price for the token
     * @param _price The new price to set
     * @notice This function allows the owner to update the token price
     * @custom:security Only the owner can set prices
     */
    function setPrice(uint256 _price) public onlyOwner {
        roundId = 1;
        price = _price;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    /**
     * @dev Returns the latest round data in Chainlink format
     * @return roundId The round ID
     * @return price The current price
     * @return startedAt Timestamp when the round started
     * @return updatedAt Timestamp when the price was last updated
     * @return answeredInRound The round ID in which the answer was computed
     * @notice This function mimics Chainlink's latestRoundData interface
     */
    function latestRoundData() public view returns (uint80, uint256, uint256, uint256, uint80) {
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }
}
