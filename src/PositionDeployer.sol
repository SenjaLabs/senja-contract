// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Position} from "./Position.sol";

/**
 * @title PositionDeployer
 * @author Senja Protocol
 * @notice A factory contract for deploying new Position instances
 * @dev This contract is responsible for creating new positions with specified parameters
 *
 * The PositionDeployer allows the factory to create new positions with different
 * collateral and borrow token pairs, along with configurable loan-to-value (LTV) ratios.
 * Each deployed position is a separate contract instance that manages position and borrowing
 * operations for a specific token pair.
 */
contract PositionDeployer {
    error OnlyOwnerCanCall();

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert OnlyOwnerCanCall();
    }

    /**
     * @notice Deploys a new Position contract with specified parameters
     * @param _lendingPool The address of the lending pool contract
     * @param _user The address of the user
     * @return The address of the newly deployed Position contract
     *
     * @dev This function creates a new Position instance with the provided parameters.
     * Only the factory contract should call this function to ensure proper pool management.
     *
     * Requirements:
     * - _lendingPool must be a valid lending pool contract address
     * - _user must be a valid user address
     *
     * @custom:security This function should only be called by the factory contract
     */
    function deployPosition(address _lendingPool, address _user) public returns (address) {
        // Deploy the Position with the provided router
        Position position = new Position(_lendingPool, _user);

        return address(position);
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
}
