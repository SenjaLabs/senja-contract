// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LendingPoolRouter} from "./LendingPoolRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LendingPoolRouterDeployer
 * @notice Factory contract responsible for deploying new LendingPoolRouter instances
 * @dev This contract is owned and only the designated factory address can trigger router deployments.
 * The deployer pattern separates deployment logic from the factory contract, allowing for upgradeable deployment strategies.
 */
contract LendingPoolRouterDeployer is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a caller other than the factory attempts to deploy a router
     */
    error OnlyFactoryCanCall();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new LendingPoolRouter is successfully deployed
     * @param router The address of the newly deployed LendingPoolRouter contract
     * @param collateralToken The address of the collateral token used in the router
     * @param borrowToken The address of the borrow token used in the router
     * @param ltv The loan-to-value ratio configured for the router (in basis points or percentage)
     */
    event LendingPoolRouterDeployed(
        address indexed router, address indexed collateralToken, address indexed borrowToken, uint256 ltv
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The most recently deployed LendingPoolRouter instance
    LendingPoolRouter public router;

    /// @notice The authorized factory address that can trigger router deployments
    address public factory;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the LendingPoolRouterDeployer contract
     * @dev Sets the deployer (msg.sender) as the initial owner via Ownable constructor
     */
    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts function access to only the factory address
     * @dev Calls internal _onlyFactory() function to validate caller
     */
    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys a new LendingPoolRouter contract with specified parameters
     * @dev Can only be called by the authorized factory address. The router is deployed with
     * address(0) as the initial owner parameter (may be configured post-deployment).
     * @param _factory The factory address to be set in the new router
     * @param _collateralToken The address of the token to be used as collateral
     * @param _borrowToken The address of the token to be borrowed
     * @param _ltv The loan-to-value ratio for the lending pool
     * @return The address of the newly deployed LendingPoolRouter
     */
    function deployLendingPoolRouter(address _factory, address _collateralToken, address _borrowToken, uint256 _ltv)
        public
        onlyFactory
        returns (address)
    {
        router = new LendingPoolRouter(address(0), _factory, _collateralToken, _borrowToken, _ltv);
        emit LendingPoolRouterDeployed(address(router), _collateralToken, _borrowToken, _ltv);
        return address(router);
    }

    /**
     * @notice Updates the authorized factory address
     * @dev Can only be called by the contract owner. This allows changing which address
     * can trigger router deployments.
     * @param _factory The new factory address to authorize
     */
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal validation function that ensures caller is the factory
     * @dev Reverts with OnlyFactoryCanCall error if msg.sender is not the factory address
     */
    function _onlyFactory() internal view {
        if (msg.sender != factory) revert OnlyFactoryCanCall();
    }
}
