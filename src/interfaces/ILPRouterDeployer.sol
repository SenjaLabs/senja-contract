// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILPRouterDeployer {
    function deployLendingPoolRouter(address _factory, address _collateralToken, address _borrowToken, uint256 _ltv)
        external
        returns (address);
}
