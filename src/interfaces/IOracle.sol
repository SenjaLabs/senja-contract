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
 * @title IOracle
 * @dev Interface for price oracle functionality
 * @notice This interface defines the contract for price feeds and token calculations
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
 * @custom:version 1.0.0
 */
interface IOracle {
    /**
     * @dev Calculates the equivalent amount of one token in terms of another
     * @param _amount Amount of tokens to convert
     * @param _tokenFrom Address of the source token
     * @param _tokenTo Address of the target token
     * @return The calculated equivalent amount
     * @notice This function performs token-to-token price calculations
     */
    function tokenCalculator(uint256 _amount, address _tokenFrom, address _tokenTo) external view returns (uint256);
    
    /**
     * @dev Gets the price ratio between collateral and borrow tokens
     * @param _collateral Address of the collateral token
     * @param _borrow Address of the borrow token
     * @return The price ratio between the tokens
     * @notice This function is used for LTV calculations
     */
    function getPrice(address _collateral, address _borrow) external view returns (uint256);
    
    /**
     * @dev Gets the price and trade information for a token pair
     * @param _tokenFrom Address of the source token
     * @param _tokenTo Address of the target token
     * @return price The price of the token pair
     * @return tradeInfo Additional trade information
     * @notice This function provides detailed pricing for trading operations
     */
    function getPriceTrade(address _tokenFrom, address _tokenTo) external view returns (uint256, uint256);
    
    /**
     * @dev Gets the decimal places for a token's quote
     * @param _token Address of the token
     * @return The number of decimal places for the token's quote
     * @notice This function helps normalize price calculations
     */
    function getQuoteDecimal(address _token) external view returns (uint256);
    
    /**
     * @dev Gets the price of a collateral token
     * @param _token Address of the collateral token
     * @return The price of the collateral token
     * @notice This function is used for collateral valuation
     */
    function priceCollateral(address _token) external view returns (uint256);
}
