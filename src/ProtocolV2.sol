// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWrappedNative} from "./interfaces/IWrappedNative.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";

/**
 * @title ProtocolV2
 * @notice This contract handles protocol-level operations including fee collection, buyback execution, and withdrawals
 * @dev Protocol contract for managing protocol fees and withdrawals with automated buyback functionality
 * @dev Implements a 95/5 split between protocol locked balance and owner available balance for buybacks
 * @author Senja Team
 * @custom:version 2.0.0
 * @custom:security-contact security@senja.io
 */
contract ProtocolV2 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Address of the Wrapped Native token contract (e.g., WKAIA)
    /// @dev Hardcoded to prevent manipulation of critical infrastructure address
    address public constant WRAPPED_NATIVE = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;

    /// @notice Address of the DEX router for executing swaps
    /// @dev Used for buyback operations to swap tokens for Wrapped Native
    address public constant DEX_ROUTER = 0xA324880f884036E3d21a09B90269E1aC57c7EC8a;

    /// @notice Protocol's share of buyback proceeds (95%)
    /// @dev This portion is locked and tracked separately from owner's share
    uint256 public constant PROTOCOL_SHARE = 95;

    /// @notice Owner's share of buyback proceeds (5%)
    /// @dev This portion is available for owner withdrawal
    uint256 public constant OWNER_SHARE = 5;

    /// @notice Divisor for percentage calculations
    /// @dev Used to calculate shares: amount * SHARE / PERCENTAGE_DIVISOR
    uint256 public constant PERCENTAGE_DIVISOR = 100;

    // ============ State Variables ============

    /// @notice Mapping of token addresses to protocol's locked balance
    /// @dev Tracks the 95% protocol share from buybacks that is locked
    /// @dev Token address => locked amount for protocol
    mapping(address => uint256) public protocolLockedBalance;

    /// @notice Mapping of token addresses to owner's available balance
    /// @dev Tracks the 5% owner share from buybacks that is available for withdrawal
    /// @dev Token address => available amount for owner
    mapping(address => uint256) public ownerAvailableBalance;

    // ============ Errors ============

    /**
     * @notice Thrown when there are insufficient tokens for withdrawal
     * @param token Address of the token with insufficient balance
     * @param amount Amount that was attempted to withdraw
     */
    error InsufficientBalance(address token, uint256 amount);

    /**
     * @notice Thrown when a swap operation fails on the DEX
     * @param tokenIn Address of the input token being swapped
     * @param tokenOut Address of the output token expected
     * @param amountIn Amount of input tokens that failed to swap
     */
    error SwapFailed(address tokenIn, address tokenOut, uint256 amountIn);

    /**
     * @notice Thrown when the output amount from a swap is less than the minimum expected
     * @param expectedMinimum Expected minimum output amount specified
     * @param actualOutput Actual output amount received from the swap
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
     * @notice Thrown when the transaction deadline has passed
     */
    error DeadlinePassed();

    /**
     * @notice Thrown when attempting to swap Wrapped Native for Wrapped Native
     * @dev This would be a no-op and waste gas, so it's prevented
     */
    error CannotSwapWNativeForWNative();

    // ============ Events ============

    /**
     * @notice Emitted when a buyback operation is successfully executed
     * @param tokenIn Address of the input token used for the buyback
     * @param totalAmountIn Total amount of input tokens used in the buyback
     * @param protocolAmount Amount of input tokens allocated to protocol (95%)
     * @param ownerAmount Amount of input tokens allocated to owner (5%)
     * @param wnativeReceived Total amount of Wrapped Native received from the buyback
     */
    event BuybackExecuted(
        address indexed tokenIn,
        uint256 totalAmountIn,
        uint256 protocolAmount,
        uint256 ownerAmount,
        uint256 wnativeReceived
    );

    // ============ Constructor ============

    /**
     * @notice Initializes the ProtocolV2 contract
     * @dev Sets the deployer as the initial owner via the Ownable constructor
     * @dev Inherits ReentrancyGuard protection for all nonReentrant functions
     */
    constructor() Ownable(msg.sender) {}

    // ============ Receive & Fallback Functions ============

    /**
     * @notice Allows the contract to receive native tokens and automatically wraps them
     * @dev Automatically converts received native tokens to Wrapped Native for consistent handling
     * @dev Required for protocol fee collection in native tokens
     */
    receive() external payable {
        if (msg.value > 0) {
            // Always wrap native tokens to Wrapped Native for consistent handling
            IWrappedNative(WRAPPED_NATIVE).deposit{value: msg.value}();
        }
    }

    /**
     * @notice Fallback function that rejects calls with data
     * @dev Prevents accidental interactions with the contract using invalid function selectors
     */
    fallback() external {
        revert("Fallback not allowed");
    }

    // ============ External Functions ============

    /**
     * @notice Executes a buyback using the protocol's accumulated token balance
     * @dev Swaps tokens for Wrapped Native and splits the output 95/5 between protocol and owner
     * @dev Protected against reentrancy attacks
     * @param tokenIn Address of the token to use for the buyback
     * @param amountIn Amount of tokens to use for the buyback
     * @param amountOutMinimum Minimum amount of Wrapped Native to receive (slippage protection)
     * @param fee Fee tier for the swap (e.g., 500 for 0.05%, 3000 for 0.3%, 10000 for 1%)
     * @param deadline Unix timestamp after which the transaction will revert
     * @return totalWNativeReceived Total amount of Wrapped Native received from the buyback
     * @custom:security Requires owner privileges to execute
     * @custom:throws InvalidTokenAddress if tokenIn is zero address
     * @custom:throws InvalidAmount if amountIn is zero
     * @custom:throws DeadlinePassed if deadline has expired
     * @custom:throws CannotSwapWNativeForWNative if tokenIn is Wrapped Native
     * @custom:throws InsufficientBalance if protocol doesn't have enough tokens
     * @custom:throws SwapFailed if the DEX swap operation fails
     */
    function executeBuyback(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint24 fee, uint256 deadline)
        external
        nonReentrant
        returns (uint256 totalWNativeReceived)
    {
        return _executeBuyback(tokenIn, amountIn, amountOutMinimum, fee, deadline);
    }

    /**
     * @notice Executes a buyback with a default 1-hour deadline for convenience
     * @dev Wrapper function that calls _executeBuyback with block.timestamp + 3600 as deadline
     * @dev Only callable by the contract owner
     * @param tokenIn Address of the token to use for the buyback
     * @param amountIn Amount of tokens to use for the buyback
     * @param amountOutMinimum Minimum amount of Wrapped Native to receive (slippage protection)
     * @param fee Fee tier for the swap (e.g., 500 for 0.05%, 3000 for 0.3%, 10000 for 1%)
     * @return totalWNativeReceived Total amount of Wrapped Native received from the buyback
     * @custom:security Requires owner privileges to execute
     */
    function executeBuybackSimple(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint24 fee)
        external
        onlyOwner
        returns (uint256 totalWNativeReceived)
    {
        return _executeBuyback(tokenIn, amountIn, amountOutMinimum, fee, block.timestamp + 3600);
    }

    /**
     * @notice Withdraws tokens from the protocol contract with option to unwrap
     * @dev Allows the owner to withdraw accumulated protocol fees
     * @dev Protected against reentrancy attacks
     * @param token Address of the token to withdraw (can be Wrapped Native or any ERC20)
     * @param amount Amount of tokens to withdraw
     * @param unwrapToNative If true and token is Wrapped Native, unwraps to native token before sending
     * @custom:security Only the owner can withdraw tokens
     * @custom:throws InsufficientBalance if contract doesn't have enough tokens
     */
    function withdraw(address token, uint256 amount, bool unwrapToNative) public nonReentrant onlyOwner {
        if (token == WRAPPED_NATIVE) {
            // Handle Wrapped Native withdrawal
            if (IERC20(WRAPPED_NATIVE).balanceOf(address(this)) < amount) {
                revert InsufficientBalance(token, amount);
            }

            if (unwrapToNative) {
                // Unwrap Wrapped Native to native and send to owner
                IWrappedNative(WRAPPED_NATIVE).withdraw(amount);
                (bool sent,) = msg.sender.call{value: amount}("");
                require(sent, "Failed to send native token");
            } else {
                // Send Wrapped Native directly to owner
                IERC20(WRAPPED_NATIVE).safeTransfer(msg.sender, amount);
            }
        } else {
            // Handle ERC20 token withdrawal
            if (IERC20(token).balanceOf(address(this)) < amount) {
                revert InsufficientBalance(token, amount);
            }
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Withdraws tokens from the protocol contract (backward compatibility)
     * @dev Defaults to not unwrapping Wrapped Native tokens
     * @dev Overloaded version of withdraw that calls the main withdraw function
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     * @custom:security Only the owner can withdraw tokens
     */
    function withdraw(address token, uint256 amount) public nonReentrant onlyOwner {
        withdraw(token, amount, false);
    }

    /**
     * @notice Withdraws from the owner's available balance (5% share from buybacks)
     * @dev Owner can only withdraw up to their tracked available balance
     * @dev Protected against reentrancy attacks
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw from owner's balance
     * @param unwrapToNative If true and token is Wrapped Native, unwraps to native token before sending
     * @custom:security Only the owner can withdraw their balance
     * @custom:throws InsufficientBalance if owner doesn't have enough available balance
     */
    function withdrawOwnerBalance(address token, uint256 amount, bool unwrapToNative) public nonReentrant onlyOwner {
        if (amount > ownerAvailableBalance[token]) {
            revert InsufficientBalance(token, amount);
        }

        ownerAvailableBalance[token] -= amount;

        if (token == WRAPPED_NATIVE) {
            // Handle Wrapped Native withdrawal
            if (unwrapToNative) {
                // Unwrap Wrapped Native to native and send to owner
                IWrappedNative(WRAPPED_NATIVE).withdraw(amount);
                (bool sent,) = msg.sender.call{value: amount}("");
                require(sent, "Failed to send native token");
            } else {
                // Send Wrapped Native directly to owner
                IERC20(WRAPPED_NATIVE).safeTransfer(msg.sender, amount);
            }
        } else {
            // Handle ERC20 token withdrawal
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Withdraws from the owner's available balance (backward compatibility)
     * @dev Defaults to not unwrapping Wrapped Native tokens
     * @dev Overloaded version that calls the main withdrawOwnerBalance function
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw from owner's balance
     * @custom:security Only the owner can withdraw their balance
     */
    function withdrawOwnerBalance(address token, uint256 amount) public onlyOwner {
        withdrawOwnerBalance(token, amount, false);
    }

    // ============ View Functions ============

    /**
     * @notice Gets the protocol's locked balance for a specific token
     * @dev Returns the 95% protocol share from buybacks that is locked
     * @param token Address of the token to query
     * @return The locked balance amount for the protocol
     */
    function getProtocolLockedBalance(address token) public view returns (uint256) {
        return protocolLockedBalance[token];
    }

    /**
     * @notice Gets the owner's available balance for a specific token
     * @dev Returns the 5% owner share from buybacks that is available for withdrawal
     * @param token Address of the token to query
     * @return The available balance amount for the owner
     */
    function getOwnerAvailableBalance(address token) public view returns (uint256) {
        return ownerAvailableBalance[token];
    }

    /**
     * @notice Gets the total balance held by the protocol contract for a specific token
     * @dev Returns the actual ERC20 balance, which includes both locked and available amounts
     * @param token Address of the token to query
     * @return The total token balance held by the protocol contract
     */
    function getTotalProtocolBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // ============ Internal Functions ============

    /**
     * @notice Internal function to execute the buyback logic
     * @dev Validates inputs, performs swaps, and updates balances accordingly
     * @dev Splits the swap into two parts: 95% for protocol (locked) and 5% for owner (available)
     * @param tokenIn Address of the token to use for the buyback
     * @param amountIn Amount of tokens to use for the buyback
     * @param amountOutMinimum Minimum amount of Wrapped Native to receive (slippage protection)
     * @param fee Fee tier for the swap (e.g., 500 for 0.05%, 3000 for 0.3%, 10000 for 1%)
     * @param deadline Unix timestamp after which the transaction will revert
     * @return totalWNativeReceived Total amount of Wrapped Native received from both swaps
     * @custom:throws InvalidTokenAddress if tokenIn is zero address
     * @custom:throws InvalidAmount if amountIn is zero
     * @custom:throws DeadlinePassed if deadline has expired
     * @custom:throws CannotSwapWNativeForWNative if tokenIn is Wrapped Native
     * @custom:throws InsufficientBalance if protocol doesn't have enough tokens
     * @custom:throws SwapFailed if either DEX swap operation fails
     */
    function _executeBuyback(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint24 fee, uint256 deadline)
        internal
        returns (uint256 totalWNativeReceived)
    {
        // Validate inputs
        if (tokenIn == address(0)) revert InvalidTokenAddress();
        if (amountIn == 0) revert InvalidAmount();
        if (deadline <= block.timestamp) revert DeadlinePassed();
        if (tokenIn == WRAPPED_NATIVE) revert CannotSwapWNativeForWNative();

        // Check if protocol has sufficient balance
        uint256 protocolBalance = IERC20(tokenIn).balanceOf(address(this));
        if (protocolBalance < amountIn) {
            revert InsufficientBalance(tokenIn, amountIn);
        }

        // Calculate shares
        uint256 protocolAmount = (amountIn * PROTOCOL_SHARE) / PERCENTAGE_DIVISOR;
        uint256 ownerAmount = amountIn - protocolAmount; // Remaining amount for owner

        // Approve DEX router to spend tokens
        IERC20(tokenIn).approve(DEX_ROUTER, amountIn);

        // Prepare swap parameters for protocol share
        IDexRouter.ExactInputSingleParams memory params = IDexRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: WRAPPED_NATIVE,
            fee: fee,
            recipient: address(this), // Send to protocol
            deadline: deadline,
            amountIn: protocolAmount,
            amountOutMinimum: (amountOutMinimum * PROTOCOL_SHARE) / PERCENTAGE_DIVISOR,
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap for protocol share
        uint256 protocolWNativeReceived;
        try IDexRouter(DEX_ROUTER).exactInputSingle(params) returns (uint256 _amountOut) {
            protocolWNativeReceived = _amountOut;
        } catch {
            revert SwapFailed(tokenIn, WRAPPED_NATIVE, protocolAmount);
        }

        // Update protocol locked balance
        protocolLockedBalance[WRAPPED_NATIVE] += protocolWNativeReceived;

        // If there's an owner amount, execute swap for owner
        uint256 ownerWNativeReceived = 0;
        if (ownerAmount > 0) {
            // Prepare swap parameters for owner share
            params.amountIn = ownerAmount;
            params.recipient = owner();
            params.amountOutMinimum = (amountOutMinimum * OWNER_SHARE) / PERCENTAGE_DIVISOR;

            try IDexRouter(DEX_ROUTER).exactInputSingle(params) returns (uint256 _amountOut) {
                ownerWNativeReceived = _amountOut;
                ownerAvailableBalance[WRAPPED_NATIVE] += ownerWNativeReceived;
            } catch {
                revert SwapFailed(tokenIn, WRAPPED_NATIVE, ownerAmount);
            }
        }

        totalWNativeReceived = protocolWNativeReceived + ownerWNativeReceived;

        // Emit buyback event
        emit BuybackExecuted(tokenIn, amountIn, protocolAmount, ownerAmount, totalWNativeReceived);
    }
}
