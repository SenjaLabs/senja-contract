// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOrakl} from "./interfaces/IOrakl.sol";

/**
 * @title Oracle
 * @author Senja Team
 * @notice Oracle price feed contract that interfaces with Orakl Network for price data
 * @dev This contract acts as an adapter between the Senja protocol and Orakl Network's price feeds,
 * providing Chainlink-compatible interface for price queries. It wraps Orakl's oracle functionality
 * and maintains round data for price tracking.
 * @custom:version 1.0.0
 * @custom:security-contact security@senja.io
 */
contract Oracle is Ownable {
    // ============ State Variables ============

    /// @notice Address of the Orakl Network oracle contract that provides price data
    /// @dev This oracle is the source of truth for price information
    address public oracle;

    /// @notice Current round ID for the price feed
    /// @dev Tracks the identifier of the current price update round
    uint80 public roundId;

    /// @notice Current price of the asset tracked by this oracle
    /// @dev Stored locally but primarily fetched from the Orakl oracle
    uint256 public price;

    /// @notice Timestamp when the current round started
    /// @dev Used for tracking when a price update round began
    uint256 public startedAt;

    /// @notice Timestamp when the price was last updated
    /// @dev Reflects the most recent price update time from the oracle
    uint256 public updatedAt;

    /// @notice Round ID in which the current answer was computed
    /// @dev Used for tracking which round produced the current price answer
    uint80 public answeredInRound;

    // ============ Constructor ============

    /**
     * @notice Initializes the Oracle contract with an Orakl Network oracle address
     * @dev Sets the owner to msg.sender via Ownable constructor and stores the oracle address
     * @param _oracle Address of the Orakl Network oracle contract to use for price data
     */
    constructor(address _oracle) Ownable(msg.sender) {
        oracle = _oracle;
    }

    // ============ External Functions ============

    /**
     * @notice Updates the Orakl Network oracle address used for price data
     * @dev Only callable by the contract owner. This allows switching to a different oracle if needed
     * @param _oracle The new Orakl Network oracle contract address to use
     */
    function setOracle(address _oracle) public onlyOwner {
        oracle = _oracle;
    }

    /**
     * @notice Returns the latest round data from the Orakl oracle in Chainlink-compatible format
     * @dev Fetches current price data from the Orakl oracle and formats it to match Chainlink's
     * latestRoundData interface. The startedAt and answeredInRound values use locally stored state.
     * @return idRound The round ID from the Orakl oracle
     * @return priceAnswer The current price as an unsigned integer (converted from int256)
     * @return startedAt Timestamp when the round started (from local state)
     * @return updated Timestamp when the price was last updated (from Orakl oracle)
     * @return answeredInRound The round ID in which the answer was computed (from local state)
     */
    function latestRoundData() public view returns (uint80, uint256, uint256, uint256, uint80) {
        (uint80 idRound, int256 priceAnswer, uint256 updated) = IOrakl(oracle).latestRoundData();
        return (idRound, uint256(priceAnswer), startedAt, updated, answeredInRound);
    }

    /**
     * @notice Returns the number of decimal places for the price data
     * @dev Queries the Orakl oracle for its decimal precision. This is important for correctly
     * interpreting price values (e.g., 8 decimals means price of 100000000 = 1.00)
     * @return The number of decimals used by the oracle for price representation
     */
    function decimals() public view returns (uint8) {
        return IOrakl(oracle).decimals();
    }
}
