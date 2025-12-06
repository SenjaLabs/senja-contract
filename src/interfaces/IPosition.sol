// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IPosition
 * @dev Interface for position management functionality
 * @notice This interface defines the contract for managing user positions and trading operations
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IPosition {
    /**
     * @dev Returns the current counter value
     * @return The current counter value
     * @notice This function tracks the number of positions or operations
     */
    function counter() external view returns (uint256);

    /**
     * @dev Returns the ID of a token in the token list
     * @param _token Address of the token
     * @return The ID of the token in the list
     */
    function tokenListsId(address _token) external view returns (uint256);

    /**
     * @dev Returns the token address at a specific index
     * @param _index The index in the token list
     * @return The address of the token at the specified index
     */
    function tokenLists(uint256 _index) external view returns (address);

    /**
     * @dev Withdraws collateral from a position
     * @param amount Amount of collateral to withdraw
     * @param _user Address of the user withdrawing collateral
     * @notice This function allows users to withdraw their collateral
     * @custom:security Users can only withdraw their own collateral
     */
    function withdrawCollateral(uint256 amount, address _user) external;

    /**
     * @dev Swaps tokens within a position
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param amountIn Amount of input tokens to swap
     * @param slippageTolerance Slippage tolerance for the swap
     * @return amountOut Amount of output tokens received
     * @notice This function allows users to swap tokens within their position
     * @custom:security Users must have sufficient balance of the input token
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        external
        returns (uint256 amountOut);

    /**
     * @dev Calculates token conversion rates
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _amountIn Amount of input tokens
     * @param _tokenInPrice Address of the input token price feed
     * @param _tokenOutPrice Address of the output token price feed
     * @return The calculated output amount
     * @notice This function performs price-based token calculations
     */
    function tokenCalculator(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _tokenInPrice,
        address _tokenOutPrice
    ) external view returns (uint256);

    /**
     * @dev Repays debt using selected token
     * @param _token Address of the token used for repayment
     * @param _amount Amount to repay
     * @param _amountOutMinimum Minimum amount of output tokens expected from swap
     * @notice This function allows users to repay their debt
     * @custom:security Users must approve tokens before calling this function
     */
    function repayWithSelectedToken(address _token, uint256 _amount, uint256 _amountOutMinimum) external payable;

    /**
     * @dev Returns the total collateral value in the position
     * @return The total collateral amount
     */
    function totalCollateral() external view returns (uint256);

    /**
     * @notice Liquidates a position and transfers collateral to the liquidator
     * @param _liquidator Address of the liquidator
     */
    function liquidation(address _liquidator) external;

    /**
     * @notice Swaps a token to the borrow token
     * @param _token Address of the input token
     * @param _amount Amount of input tokens to swap
     * @param _amountOutMinimum Minimum amount of borrow tokens expected from swap
     */
    function swapTokenToBorrow(address _token, uint256 _amount, uint256 _amountOutMinimum) external;
}
