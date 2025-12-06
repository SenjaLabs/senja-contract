// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MOCKUSDT
 * @notice Mock Tether USD token for testing purposes
 * @dev Extends OpenZeppelin's ERC20 with 6 decimals and public mint/burn functions
 */
contract MOCKUSDT is ERC20 {
    /**
     * @notice Constructs a new mock USDT token
     * @dev Initializes with name "USDT" and symbol "USDT"
     */
    constructor() ERC20("USDT", "USDT") {}

    /**
     * @notice Returns the number of decimals used for the token
     * @return Number of decimal places (6 for USDT)
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Mints tokens to a specified address
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     * @dev Public function for testing - no access control
     */
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    /**
     * @notice Burns tokens from a specified address
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     * @dev Public function for testing - no access control
     */
    function burn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }
}
