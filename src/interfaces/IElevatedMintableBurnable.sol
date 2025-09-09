// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IElevatedMintableBurnable {
    function burn(address _from, uint256 _amount) external returns (bool success);
    function mint(address _to, uint256 _amount) external returns (bool success);
}
