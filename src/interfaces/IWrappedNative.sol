// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IWrappedNative
 * @notice Interface for wrapped native token functionality
 * @dev Extends IERC20 with deposit and withdraw functions for wrapping/unwrapping native tokens
 */
interface IWrappedNative is IERC20 {
    /**
     * @notice Deposits native tokens and mints equivalent wrapped tokens
     * @dev Payable function that wraps the sent native tokens
     */
    function deposit() external payable;

    /**
     * @notice Withdraws wrapped tokens and returns equivalent native tokens
     * @param wad Amount of wrapped tokens to unwrap
     */
    function withdraw(uint256 wad) external;
}
