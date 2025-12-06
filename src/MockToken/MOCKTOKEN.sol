// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MOCKTOKEN
 * @notice Generic mock ERC20 token with configurable decimals for testing purposes
 * @dev Extends OpenZeppelin's ERC20 with public mint and burn functions
 */
contract MOCKTOKEN is ERC20 {
    /// @dev Immutable decimal places for the token
    uint8 private immutable _DECIMALS;

    /**
     * @notice Constructs a new mock token
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     * @param __decimals Number of decimal places for the token
     */
    constructor(string memory _name, string memory _symbol, uint8 __decimals) ERC20(_name, _symbol) {
        _DECIMALS = __decimals;
    }

    /**
     * @notice Returns the number of decimals used for the token
     * @return Number of decimal places
     */
    function decimals() public view virtual override returns (uint8) {
        return _DECIMALS;
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
