// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IProtocol
 * @dev Interface for protocol contract
 * @notice This interface defines the contract for protocol operations
 * @author Senja Labs
 * @custom:version 1.0.0
 */
interface IProtocol {
    /**
     * @notice Gets the protocol fee for a token
     * @param _token The address of the token
     * @return The protocol fee for the token
     */
    function getProtocolFee(address _token) external view returns (uint256);
}
