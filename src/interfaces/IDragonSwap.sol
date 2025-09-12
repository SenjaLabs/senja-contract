// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IDragonSwap
 * @dev Interface for DragonSwap router functionality
 * @notice This interface defines the contract for token swapping operations on DragonSwap
 * @author Senja Team
 * @custom:security-contact security@senja.com
 * @custom:version 1.0.0
 */
interface IDragonSwap {
    /**
     * @dev Parameters for exact input single token swap
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param fee Fee tier for the swap
     * @param recipient Address to receive the output tokens
     * @param deadline Deadline for the swap transaction
     * @param amountIn Amount of input tokens to swap
     * @param amountOutMinimum Minimum amount of output tokens to receive
     * @param sqrtPriceLimitX96 Price limit for the swap
     */
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @dev Executes an exact input single token swap
     * @param params The swap parameters
     * @return amountOut The amount of output tokens received
     * @notice This function performs a single token swap with exact input
     * @custom:security Users must approve tokens before calling this function
     */
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
