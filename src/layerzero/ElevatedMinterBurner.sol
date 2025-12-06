// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMintableBurnable} from "../interfaces/IMintableBurnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ElevatedMinterBurner
 * @notice Contract for controlled minting and burning of tokens with operator privileges
 * @dev Manages token minting and burning operations for cross-chain bridging via LayerZero
 */
contract ElevatedMinterBurner is Ownable {
    /// @notice Emitted when tokens are burned
    /// @param from The original owner address
    /// @param to The operator performing the burn
    /// @param amount Amount of tokens burned
    event Burn(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when tokens are minted
    /// @param to The recipient address
    /// @param from The operator performing the mint
    /// @param amount Amount of tokens minted
    event Mint(address indexed to, address indexed from, uint256 amount);

    /// @notice The token contract that this minter/burner controls
    address public immutable TOKEN;

    /// @notice Mapping of authorized operators who can mint and burn
    mapping(address => bool) public operators;

    using SafeERC20 for IERC20;

    /**
     * @notice Modifier to restrict function access to authorized operators only
     * @dev Allows both operators and owner to execute
     */
    modifier onlyOperators() {
        _onlyOperators();
        _;
    }

    /**
     * @dev Internal function to check operator authorization
     */
    function _onlyOperators() internal view {
        require(operators[msg.sender] || msg.sender == owner(), "Not authorized");
    }

    /**
     * @notice Constructs the ElevatedMinterBurner contract
     * @param _token Address of the token to control
     * @param _owner Address of the contract owner
     */
    constructor(address _token, address _owner) Ownable(_owner) {
        TOKEN = _token;
    }

    /**
     * @notice Sets operator status for an address
     * @param _operator Address to modify
     * @param _status True to grant operator status, false to revoke
     * @dev Only callable by contract owner
     */
    function setOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
    }

    /**
     * @notice Burns tokens from this contract
     * @param _from Original owner address (for event tracking)
     * @param _amount Amount of tokens to burn
     * @return True if burn was successful
     * @dev Transfers tokens from caller to this contract, then burns them
     */
    function burn(address _from, uint256 _amount) external onlyOperators returns (bool) {
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
        IMintableBurnable(TOKEN).burn(address(this), _amount);
        emit Burn(_from, msg.sender, _amount);
        return true;
    }

    /**
     * @notice Mints new tokens to a recipient
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     * @return True if mint was successful
     * @dev Only callable by authorized operators
     */
    function mint(address _to, uint256 _amount) external onlyOperators returns (bool) {
        IMintableBurnable(TOKEN).mint(_to, _amount);
        emit Mint(_to, msg.sender, _amount);
        return true;
    }
}
