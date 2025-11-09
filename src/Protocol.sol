// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWrappedNative} from "./interfaces/IWrappedNative.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";

/**
 * @title Protocol
 * @dev Protocol contract for managing protocol fees and withdrawals
 * @notice This contract handles protocol-level operations including fee collection and withdrawals
 * @author Senja Team
 * @custom:version 1.0.0
 */
contract Protocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Wrapped Native contract address
    address public constant WRAPPED_NATIVE = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;

    // DEX router address
    address public constant DEX_ROUTER = 0xA324880f884036E3d21a09B90269E1aC57c7EC8a;

    // Buyback configuration
    uint256 public constant PROTOCOL_SHARE = 95; // 95% for protocol (locked)
    uint256 public constant OWNER_SHARE = 5; // 5% for owner
    uint256 public constant PERCENTAGE_DIVISOR = 100;

    // State variables for buyback tracking
    mapping(address => uint256) public protocolLockedBalance; // Token => locked amount for protocol
    mapping(address => uint256) public ownerAvailableBalance; // Token => available amount for owner

    // ============ Errors ============

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

    // ============ Events ============

    /**
     * @dev Emitted when buyback is executed
     * @param tokenIn Address of the input token used for buyback
     * @param totalAmountIn Total amount of input tokens used
     * @param protocolAmount Amount allocated to protocol (locked)
     * @param ownerAmount Amount allocated to owner
     * @param wnativeReceived Total Wrapped Native received from buyback
     */
    event BuybackExecuted(
        address indexed tokenIn,
        uint256 totalAmountIn,
        uint256 protocolAmount,
        uint256 ownerAmount,
        uint256 wnativeReceived
    );

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
            IWrappedNative(WRAPPED_NATIVE).deposit{value: msg.value}();
        }
    }

    /**
     * @dev Fallback function - rejects calls with data to prevent accidental interactions
     */
    fallback() external {
        revert("Fallback not allowed");
    }

    /**
     * @dev Executes buyback using protocol's accumulated balance
     * @param tokenIn Address of the token to use for buyback
     * @param amountIn Amount of tokens to use for buyback
     * @param amountOutMinimum Minimum amount of Wrapped Native to receive (slippage protection)
     * @param fee Fee tier for the swap (0.05% = 500, 0.3% = 3000, 1% = 10000)
     * @param deadline Deadline for the swap transaction
     * @return totalWNativeReceived Total amount of Wrapped Native received from buyback
     * @notice Uses protocol's balance to buy Wrapped Native, splits 95% to protocol (locked) and 5% to owner
     * @custom:security Only the owner can execute buyback
     */
    function executeBuyback(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint24 fee, uint256 deadline)
        external
        nonReentrant
        returns (uint256 totalWNativeReceived)
    {
        return _executeBuyback(tokenIn, amountIn, amountOutMinimum, fee, deadline);
    }

    /**
     * @dev Internal function to execute buyback using protocol's accumulated balance
     * @param tokenIn Address of the token to use for buyback
     * @param amountIn Amount of tokens to use for buyback
     * @param amountOutMinimum Minimum amount of Wrapped Native to receive (slippage protection)
     * @param fee Fee tier for the swap (0.05% = 500, 0.3% = 3000, 1% = 10000)
     * @param deadline Deadline for the swap transaction
     * @return totalWNativeReceived Total amount of Wrapped Native received from buyback
     * @notice Uses protocol's balance to buy Wrapped Native, splits 95% to protocol (locked) and 5% to owner
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

    /**
     * @dev Executes buyback with default deadline (1 hour)
     * @param tokenIn Address of the token to use for buyback
     * @param amountIn Amount of tokens to use for buyback
     * @param amountOutMinimum Minimum amount of Wrapped Native to receive (slippage protection)
     * @param fee Fee tier for the swap (0.05% = 500, 0.3% = 3000, 1% = 10000)
     * @return totalWNativeReceived Total amount of Wrapped Native received from buyback
     */
    function executeBuybackSimple(address tokenIn, uint256 amountIn, uint256 amountOutMinimum, uint24 fee)
        external
        onlyOwner
        returns (uint256 totalWNativeReceived)
    {
        return _executeBuyback(tokenIn, amountIn, amountOutMinimum, fee, block.timestamp + 3600);
    }

    /**
     * @dev Withdraws tokens from the protocol contract
     * @param token Address of the token to withdraw (Wrapped Native)
     * @param amount Amount of tokens to withdraw
     * @param unwrapToNative Whether to unwrap Wrapped Native to native token
     * @notice This function allows the owner to withdraw accumulated protocol fees
     * @custom:security Only the owner can withdraw tokens
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
     * @dev Withdraws tokens from the protocol contract (backward compatibility)
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     * @notice Defaults to not unwrapping Wrapped Native
     */
    function withdraw(address token, uint256 amount) public nonReentrant onlyOwner {
        withdraw(token, amount, false);
    }

    /**
     * @dev Withdraws owner's available balance
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     * @param unwrapToNative Whether to unwrap Wrapped Native to native
     * @notice Owner can only withdraw their available balance (5% share from buybacks)
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
     * @dev Withdraws owner's available balance (backward compatibility)
     * @param token Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     * @notice Defaults to not unwrapping Wrapped Native
     */
    function withdrawOwnerBalance(address token, uint256 amount) public onlyOwner {
        withdrawOwnerBalance(token, amount, false);
    }

    /**
     * @dev Gets the total protocol locked balance for a token
     * @param token Address of the token
     * @return The locked balance for the protocol
     */
    function getProtocolLockedBalance(address token) public view returns (uint256) {
        return protocolLockedBalance[token];
    }

    /**
     * @dev Gets the owner's available balance for a token
     * @param token Address of the token
     * @return The available balance for the owner
     */
    function getOwnerAvailableBalance(address token) public view returns (uint256) {
        return ownerAvailableBalance[token];
    }

    /**
     * @dev Gets the total protocol balance (locked + available) for a token
     * @param token Address of the token
     * @return The total balance held by the protocol
     */
    function getTotalProtocolBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
