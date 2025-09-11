// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title Protocol
 * @dev Protocol contract for managing protocol fees and withdrawals
 * @notice This contract handles protocol-level operations including fee collection and withdrawals
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
 * @custom:version 1.0.0
 */
contract Protocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

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
     * @dev Allows the contract to receive native tokens (KAIA)
     * @notice Required for protocol fee collection in native tokens
     */
    receive() external payable {}

    /**
     * @dev Withdraws tokens from the protocol contract
     * @param token Address of the token to withdraw (address(1) for native KAIA)
     * @param amount Amount of tokens to withdraw
     * @notice This function allows the owner to withdraw accumulated protocol fees
     * @custom:security Only the owner can withdraw tokens
     */
    function withdraw(address token, uint256 amount) public nonReentrant onlyOwner {
        if (token == address(1)) {
            // Handle native token (KAIA) withdrawal
            if (address(this).balance < amount) {
                revert InsufficientBalance(token, amount);
            }
            (bool sent,) = msg.sender.call{value: amount}("");
            require(sent, "Failed to send native token");
        } else {
            // Handle ERC20 token withdrawal
            if (IERC20(token).balanceOf(address(this)) < amount) {
                revert InsufficientBalance(token, amount);
            }
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }
}
