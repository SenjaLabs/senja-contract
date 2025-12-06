// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IPositionDeployer
 * @notice Interface for deploying user position contracts
 * @dev Defines the contract for creating and managing position instances
 */
interface IPositionDeployer {
    /**
     * @notice Deploys a new position contract for a user
     * @param _lendingPool Address of the lending pool associated with the position
     * @param _user Address of the user who will own the position
     * @return Address of the newly deployed position contract
     */
    function deployPosition(address _lendingPool, address _user) external returns (address);

    /**
     * @notice Sets the owner of the deployer contract
     * @param _owner Address of the new owner
     */
    function setOwner(address _owner) external;
}
