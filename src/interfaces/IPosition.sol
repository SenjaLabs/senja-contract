// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title IPosition
 * @dev Interface for position management functionality
 * @notice This interface defines the contract for managing user positions and trading operations
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
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
     * @dev Lists a trading position for a token
     * @param _token Address of the token to list
     * @param _price Price for the trading position
     * @param _name Name identifier for the position
     * @notice This function creates a new trading position listing
     * @custom:security Only authorized users should be able to list positions
     */
    function listingTradingPosition(address _token, uint256 _price, string memory _name) external;
    
    /**
     * @dev Buys a trading position
     * @param _price Price to pay for the position
     * @param _buyer Address of the buyer
     * @notice This function allows users to purchase trading positions
     * @custom:security Buyers must have sufficient funds to complete the purchase
     */
    function buyTradingPosition(uint256 _price, address _buyer) external;
    
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
     * @return amountOut Amount of output tokens received
     * @notice This function allows users to swap tokens within their position
     * @custom:security Users must have sufficient balance of the input token
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 amountIn)
        external
        returns (uint256 amountOut);
    
    /**
     * @dev Repays debt using selected token
     * @param amount Amount to repay
     * @param _token Address of the token used for repayment
     * @notice This function allows users to repay their debt
     * @custom:security Users must approve tokens before calling this function
     */
    function repayWithSelectedToken(uint256 amount, address _token) external;
    
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
     * @dev Gets the value of a token
     * @param token Address of the token
     * @return The value of the token
     * @notice This function returns the current value of a token
     */
    function tokenValue(address token) external view returns (uint256);
}
