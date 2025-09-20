// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendingPoolRouter} from "./LendingPoolRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendingPoolRouterDeployer is Ownable {
    error OnlyFactoryCanCall();

    event LendingPoolRouterDeployed(
        address indexed router, address indexed collateralToken, address indexed borrowToken, uint256 ltv
    );

    LendingPoolRouter public router;
    address public factory;

    constructor() Ownable(msg.sender) {}

    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    function deployLendingPoolRouter(address _factory, address _collateralToken, address _borrowToken, uint256 _ltv)
        public
        onlyFactory
        returns (address)
    {
        router = new LendingPoolRouter(address(0), _factory, _collateralToken, _borrowToken, _ltv);
        emit LendingPoolRouterDeployed(address(router), _collateralToken, _borrowToken, _ltv);
        return address(router);
    }

    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    function _onlyFactory() internal view {
        if (msg.sender != factory) revert OnlyFactoryCanCall();
    }
}
