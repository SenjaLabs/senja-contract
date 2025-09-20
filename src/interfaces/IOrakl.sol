// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOrakl {
    function latestRoundData() external view returns (uint80, int256, uint256);
    function decimals() external view returns (uint8);
}
