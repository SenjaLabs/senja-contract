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
 * @dev Protocol contract for managing protocol fees and withdrawals
 * @notice This contract handles protocol-level operations including fee collection and withdrawals
 * @author Senja Team
 * @custom:version 1.0.0
 */
contract Protocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /**
     * @dev Error thrown when there are insufficient tokens for withdrawal
     * @param token Address of the token with insufficient balance
     * @param amount Amount that was attempted to withdraw
     */
    error InsufficientBalance(address token, uint256 amount);

    /**
     * @dev Error thrown when swap fails
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param amountIn Amount of input tokens
     */
    error SwapFailed(address tokenIn, address tokenOut, uint256 amountIn);

    /**
     * @dev Error thrown when insufficient output amount is received
     * @param expectedMinimum Expected minimum output amount
     * @param actualOutput Actual output amount received
     */
    error InsufficientOutputAmount(uint256 expectedMinimum, uint256 actualOutput);

    /**
     * @dev Error thrown when invalid token address is provided
     */
    error InvalidTokenAddress();

    /**
     * @dev Error thrown when amount is zero or invalid
     */
    error InvalidAmount();

    /**
     * @dev Error thrown when deadline has passed
     */
    error DeadlinePassed();

    /**
     * @dev Error thrown when trying to swap Wrapped Native for Wrapped Native
     */
    error CannotSwapWNativeForWNative();

    /**
     * @dev Error thrown when lending pool factory is not set
     */
    error LendingPoolFactoryNotSet();

    // ============ Events ============

    event Withdraw(address token, uint256 amount);
    event LendingPoolFactorySet(address lendingPoolFactory);

    address public lendingPoolFactory;

    /**
     * @dev Constructor for the Protocol contract
     * @notice Initializes the protocol contract with the deployer as owner
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Allows the contract to receive native tokens and auto-wraps them to Wrapped Native
     * @notice Required for protocol fee collection in native tokens
     */
    receive() external payable {
        if (msg.value > 0) {
            // Always wrap native tokens to Wrapped Native for consistent handling
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
        }
    }

    /**
     * @dev Fallback function - rejects calls with data to prevent accidental interactions
     */
    fallback() external {
        revert("Fallback not allowed");
    }

    function withdraw(address _token, uint256 _amount) public nonReentrant onlyOwner {
        if (IERC20(_token).balanceOf(address(this)) < _amount) {
            revert InsufficientBalance(_token, _amount);
        }

        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Withdraw(_token, _amount);
    }

    function setLendingPoolFactory(address _lendingPoolFactory) public onlyOwner {
        lendingPoolFactory = _lendingPoolFactory;
        emit LendingPoolFactorySet(_lendingPoolFactory);
    }

    function _WRAPPED_NATIVE() internal view returns (address) {
        if (lendingPoolFactory == address(0)) revert LendingPoolFactoryNotSet();
        return IFactory(lendingPoolFactory).WRAPPED_NATIVE();
    }
}
