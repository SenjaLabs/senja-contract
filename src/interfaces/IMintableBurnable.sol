// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMintableBurnable {
    function burn(uint256 _amount) external;
    function burnFrom(address _from, uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;
}
