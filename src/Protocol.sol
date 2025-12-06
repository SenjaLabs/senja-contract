// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWrappedNative} from "./interfaces/IWrappedNative.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";

import {IFactory} from "./interfaces/IFactory.sol";

/**
 * @title Protocol
 * @notice This contract manages protocol-level operations including fee collection and withdrawals
 * @dev Protocol contract for managing protocol fees, native token wrapping, and withdrawal operations.
 *      Inherits from ReentrancyGuard for protection against reentrancy attacks and Ownable for access control.
 *      The contract automatically wraps received native tokens to Wrapped Native tokens for consistent handling.
 * @author Senja Team
 * @custom:version 1.0.0
 * @custom:security-contact security@senja.io
 */
contract Protocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Errors ============

    /**
     * @notice Thrown when attempting to withdraw more tokens than the contract holds
     * @param token The address of the token with insufficient balance
     * @param amount The amount that was attempted to be withdrawn
     */
    error InsufficientBalance(address token, uint256 amount);

    /**
     * @notice Thrown when a token swap operation fails
     * @param tokenIn The address of the input token being swapped
     * @param tokenOut The address of the output token expected from the swap
     * @param amountIn The amount of input tokens that failed to swap
     */
    error SwapFailed(address tokenIn, address tokenOut, uint256 amountIn);

    /**
     * @notice Thrown when the swap output amount is less than the expected minimum
     * @param expectedMinimum The minimum output amount that was expected
     * @param actualOutput The actual output amount received from the swap
     */
    error InsufficientOutputAmount(uint256 expectedMinimum, uint256 actualOutput);

    /**
     * @notice Thrown when an invalid token address (zero address) is provided
     */
    error InvalidTokenAddress();

    /**
     * @notice Thrown when an amount is zero or invalid
     */
    error InvalidAmount();

    /**
     * @notice Thrown when a transaction deadline has expired
     */
    error DeadlinePassed();

    /**
     * @notice Thrown when attempting to swap Wrapped Native tokens for Wrapped Native tokens
     */
    error CannotSwapWNativeForWNative();

    /**
     * @notice Thrown when the lending pool factory address has not been configured
     */
    error LendingPoolFactoryNotSet();

    // ============ Events ============

    /**
     * @notice Emitted when tokens are withdrawn from the protocol
     * @param token The address of the token that was withdrawn
     * @param amount The amount of tokens that were withdrawn
     */
    event Withdraw(address token, uint256 amount);

    /**
     * @notice Emitted when the lending pool factory address is set or updated
     * @param lendingPoolFactory The address of the new lending pool factory
     */
    event LendingPoolFactorySet(address lendingPoolFactory);

    // ============ State Variables ============

    /// @notice The address of the lending pool factory contract used to retrieve wrapped native token address
    address public lendingPoolFactory;

    // ============ Constructor ============

    /**
     * @notice Initializes the Protocol contract
     * @dev Sets the deployer as the initial owner through the Ownable constructor
     *      The lending pool factory must be set separately using setLendingPoolFactory()
     */
    constructor() Ownable(msg.sender) {}

    // ============ Receive & Fallback Functions ============

    /**
     * @notice Receives native tokens and automatically wraps them to Wrapped Native tokens
     * @dev Required for protocol fee collection in native tokens. All received native tokens
     *      are automatically converted to Wrapped Native tokens to maintain consistent token handling.
     *      Reverts if the lending pool factory is not set or if wrapping fails.
     */
    receive() external payable {
        if (msg.value > 0) {
            // Always wrap native tokens to Wrapped Native for consistent handling
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
        }
    }

    /**
     * @notice Fallback function that rejects all calls with data
     * @dev Prevents accidental interactions with the contract using invalid function signatures
     *      or calldata. Always reverts when called.
     */
    fallback() external {
        revert("Fallback not allowed");
    }

    // ============ External Functions ============

    /**
     * @notice Withdraws tokens from the protocol to the owner
     * @dev Protected by nonReentrant modifier to prevent reentrancy attacks.
     *      Only the contract owner can call this function.
     * @param _token The address of the token to withdraw
     * @param _amount The amount of tokens to withdraw
     * @custom:throws InsufficientBalance If the contract doesn't hold enough of the specified token
     * @custom:emits Withdraw When tokens are successfully withdrawn
     */
    function withdraw(address _token, uint256 _amount) public nonReentrant onlyOwner {
        if (IERC20(_token).balanceOf(address(this)) < _amount) {
            revert InsufficientBalance(_token, _amount);
        }

        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Withdraw(_token, _amount);
    }

    /**
     * @notice Sets the lending pool factory address
     * @dev Only the contract owner can update the lending pool factory address.
     *      The factory is used to retrieve the wrapped native token address.
     * @param _lendingPoolFactory The address of the lending pool factory contract
     * @custom:emits LendingPoolFactorySet When the factory address is successfully updated
     */
    function setLendingPoolFactory(address _lendingPoolFactory) public onlyOwner {
        lendingPoolFactory = _lendingPoolFactory;
        emit LendingPoolFactorySet(_lendingPoolFactory);
    }

    // ============ Internal Functions ============

    /**
     * @notice Retrieves the wrapped native token address from the lending pool factory
     * @dev Internal view function that queries the factory for the wrapped native token address.
     *      This provides a centralized configuration point for the wrapped native token.
     * @return The address of the wrapped native token
     * @custom:throws LendingPoolFactoryNotSet If the lending pool factory has not been configured
     */
    function _WRAPPED_NATIVE() internal view returns (address) {
        if (lendingPoolFactory == address(0)) revert LendingPoolFactoryNotSet();
        return IFactory(lendingPoolFactory).WRAPPED_NATIVE();
    }
}
