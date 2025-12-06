// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IMintableBurnable
 * @notice Interface for tokens with basic mint and burn functionality
 * @dev Defines the standard functions for minting and burning tokens
 */
interface IMintableBurnable {
    /**
     * @notice Burns tokens from a specified address
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external;

    /**
     * @notice Mints new tokens to a specified address
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external;
}
