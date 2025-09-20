// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPositionDeployer {
    function deployPosition(address _lendingPool, address _user) external returns (address);
    function setOwner(address _owner) external;
}
