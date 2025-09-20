// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LendingPool} from "./LendingPool.sol";

/**
 * @title LendingPoolDeployer
 * @author Senja Protocol
 * @notice A factory contract for deploying new LendingPool instances
 * @dev This contract is responsible for creating new lending pools with specified parameters
 *
 * The LendingPoolDeployer allows the factory to create new lending pools with different
 * collateral and borrow token pairs, along with configurable loan-to-value (LTV) ratios.
 * Each deployed pool is a separate contract instance that manages lending and borrowing
 * operations for a specific token pair.
 */
contract LendingPoolDeployer {
    error OnlyFactoryCanCall();
    error OnlyOwnerCanCall();

    // Factory address
    address public factory;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    function _onlyFactory() internal view {
        if (msg.sender != factory) revert OnlyFactoryCanCall();
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert OnlyOwnerCanCall();
    }

    /**
     * @notice Deploys a new LendingPool contract with specified parameters
     * @param _router The address of the router contract
     * @return The address of the newly deployed LendingPool contract
     *
     * @dev This function creates a new LendingPool instance with the provided parameters.
     * Only the factory contract should call this function to ensure proper pool management.
     *
     * Requirements:
     * - _router must be a valid router contract address
     *
     * @custom:security This function should only be called by the factory contract
     */
    function deployLendingPool(address _router) public onlyFactory returns (address) {
        // Deploy the LendingPool with the provided router
        LendingPool lendingPool = new LendingPool(_router);

        return address(lendingPool);
    }

    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }
}
