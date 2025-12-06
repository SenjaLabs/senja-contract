// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IElevatedMintableBurnable
 * @notice Interface for tokens with elevated mint and burn privileges
 * @dev Extends basic mintable/burnable functionality with success return values
 */
interface IElevatedMintableBurnable {
    /**
     * @notice Burns tokens from a specified address
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     * @return success True if the burn was successful
     */
    function burn(address _from, uint256 _amount) external returns (bool success);

    /**
     * @notice Mints new tokens to a specified address
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     * @return success True if the mint was successful
     */
    function mint(address _to, uint256 _amount) external returns (bool success);
}
