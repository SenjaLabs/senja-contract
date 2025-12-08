// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Position} from "./Position.sol";

/**
 * @title PositionDeployer
 * @author Senja Labs
 * @notice A factory contract for deploying new Position instances
 * @dev This contract is responsible for creating new positions with specified parameters
 *
 * The PositionDeployer allows the factory to create new positions with different
 * collateral and borrow token pairs, along with configurable loan-to-value (LTV) ratios.
 * Each deployed position is a separate contract instance that manages position and borrowing
 * operations for a specific token pair.
 */
contract PositionDeployer {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a caller other than the owner attempts to execute an owner-only function
     */
    error OnlyOwnerCanCall();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the contract owner who has administrative privileges
    address public owner;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the PositionDeployer contract
     * @dev Sets the contract deployer as the initial owner
     */
    constructor() {
        owner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts function access to only the contract owner
     * @dev Calls internal _onlyOwner function to verify caller is the owner
     */
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /**
     * @notice Updates the owner address of the contract
     * @param _owner The address of the new owner
     * @dev Only the current owner can transfer ownership to a new address
     *
     * Requirements:
     * - Caller must be the current owner
     * - _owner should be a valid address (non-zero for safety, though not enforced)
     *
     * @custom:security Consider using a two-step ownership transfer pattern for production
     */
    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to verify that the caller is the owner
     * @dev Reverts with OnlyOwnerCanCall error if the caller is not the owner
     *
     * This function is called by the onlyOwner modifier to enforce access control.
     * Using an internal function instead of inline code in the modifier reduces
     * bytecode size when the modifier is used multiple times.
     */
    function _onlyOwner() internal view {
        if (msg.sender != owner) revert OnlyOwnerCanCall();
    }
}
