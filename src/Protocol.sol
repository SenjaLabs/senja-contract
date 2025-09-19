// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWKAIA} from "./interfaces/IWKAIA.sol";

/**
 * @title Protocol
 * @dev Protocol contract for managing protocol fees and withdrawals
 * @notice This contract handles protocol-level operations including fee collection and withdrawals
 * @author Senja Team
 * @custom:version 1.0.0
 */
contract Protocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    // WKAIA contract address on Kaia mainnet
    address public constant WKAIA = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;

    // ============ Errors ============
    
    /**
     * @dev Error thrown when there are insufficient tokens for withdrawal
     * @param token Address of the token with insufficient balance
     * @param amount Amount that was attempted to withdraw
     */
    error InsufficientBalance(address token, uint256 amount);

    /**
     * @dev Constructor for the Protocol contract
     * @notice Initializes the protocol contract with the deployer as owner
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Allows the contract to receive native tokens (KAIA) and auto-wraps them to WKAIA
     * @notice Required for protocol fee collection in native tokens
     */
    receive() external payable {
        if (msg.value > 0) {
            // Always wrap native tokens to WKAIA for consistent handling
            IWKAIA(WKAIA).deposit{value: msg.value}();
        }
    }

    /**
     * @dev Fallback function - rejects calls with data to prevent accidental interactions
     */
    fallback() external {
        revert("Fallback not allowed");
    }

    /**
     * @dev Withdraws tokens from the protocol contract
     * @param token Address of the token to withdraw (WKAIA for wrapped KAIA)
     * @param amount Amount of tokens to withdraw
     * @param unwrapToNative Whether to unwrap WKAIA to native KAIA
     * @notice This function allows the owner to withdraw accumulated protocol fees
     * @custom:security Only the owner can withdraw tokens
     */
    function withdraw(address token, uint256 amount, bool unwrapToNative) public nonReentrant onlyOwner {
        if (token == WKAIA) {
            // Handle WKAIA withdrawal
            if (IERC20(WKAIA).balanceOf(address(this)) < amount) {
                revert InsufficientBalance(token, amount);
            }
            
            if (unwrapToNative) {
                // Unwrap WKAIA to native KAIA and send to owner
                IWKAIA(WKAIA).withdraw(amount);
                (bool sent,) = msg.sender.call{value: amount}("");
                require(sent, "Failed to send native token");
            } else {
                // Send WKAIA directly to owner
                IERC20(WKAIA).safeTransfer(msg.sender, amount);
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
     * @notice Defaults to not unwrapping WKAIA
     */
    function withdraw(address token, uint256 amount) public nonReentrant onlyOwner {
        withdraw(token, amount, false);
    }
}
