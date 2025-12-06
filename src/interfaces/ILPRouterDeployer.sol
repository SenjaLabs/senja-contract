// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ILPRouterDeployer
 * @notice Interface for deploying lending pool router contracts
 * @dev Defines the contract for creating new lending pool router instances
 */
interface ILPRouterDeployer {
    /**
     * @notice Deploys a new lending pool router
     * @param _factory Address of the factory contract
     * @param _collateralToken Address of the collateral token
     * @param _borrowToken Address of the borrow token
     * @param _ltv Loan-to-value ratio for the lending pool
     * @return Address of the newly deployed lending pool router
     */
    function deployLendingPoolRouter(address _factory, address _collateralToken, address _borrowToken, uint256 _ltv)
        external
        returns (address);
}
