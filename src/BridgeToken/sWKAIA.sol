// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title sWKAIA
 * @notice Synthetic Wrapped KAIA token representing WKAIA deposits in the Senja protocol
 * @dev ERC20 token with operator-controlled minting and burning, fixed 18 decimals
 */
contract sWKAIA is ERC20, Ownable {
    /// @notice Mapping to track authorized operators who can mint and burn tokens
    mapping(address => bool) public operator;

    /// @notice Error thrown when a non-operator attempts to call operator-only functions
    error NotOperator();

    /**
     * @notice Constructs the sWKAIA token contract
     * @dev Initializes with name "Wrapped KAIA representative" and symbol "sWKAIA"
     */
    constructor() ERC20("Wrapped KAIA representative", "sWKAIA") Ownable(msg.sender) {}

    /**
     * @notice Modifier to restrict function access to authorized operators only
     * @dev Reverts with NotOperator error if caller is not an operator
     */
    modifier onlyOperator() {
        _onlyOperator();
        _;
    }

    /**
     * @dev Internal function to check if caller is an authorized operator
     * @dev Reverts with NotOperator error if caller is not an operator
     */
    function _onlyOperator() internal view {
        if (!operator[msg.sender]) revert NotOperator();
    }

    /**
     * @notice Returns the number of decimals used for token amounts
     * @return Always returns 18 decimals
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Sets or revokes operator status for an address
     * @dev Only callable by the contract owner
     * @param _operator The address to modify operator status for
     * @param _isOperator True to grant operator status, false to revoke
     */
    function setOperator(address _operator, bool _isOperator) public onlyOwner {
        operator[_operator] = _isOperator;
    }

    /**
     * @notice Mints new tokens to a specified address
     * @dev Only callable by authorized operators
     * @param _to The address to receive the minted tokens
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) public onlyOperator {
        _mint(_to, _amount);
    }

    /**
     * @notice Burns tokens from a specified address
     * @dev Only callable by authorized operators
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) public onlyOperator {
        _burn(_from, _amount);
    }
}
