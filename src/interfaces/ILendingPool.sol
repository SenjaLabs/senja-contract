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
 * @title ILendingPool
 * @dev Interface for lending pool functionality
 * @notice This interface defines the core lending pool operations including supply, borrow, and repay
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
 * @custom:version 1.0.0
 */
interface ILendingPool {
    /**
     * @dev Returns the loan-to-value ratio for the lending pool
     * @return The LTV ratio as a percentage
     */
    function ltv() external view returns (uint256);
    
    /**
     * @dev Returns the address of the collateral token
     * @return Address of the collateral token contract
     */
    function collateralToken() external view returns (address);
    
    /**
     * @dev Returns the address of the borrow token
     * @return Address of the borrow token contract
     */
    function borrowToken() external view returns (address);
    
    /**
     * @dev Supplies collateral to the lending pool
     * @param amount Amount of collateral to supply
     * @notice This function allows users to deposit collateral
     * @custom:security Users must approve tokens before calling this function
     */
    function supplyCollateral(uint256 amount) external;
    
    /**
     * @dev Supplies liquidity to the lending pool
     * @param amount Amount of liquidity to supply
     * @notice This function allows users to provide liquidity for borrowing
     * @custom:security Users must approve tokens before calling this function
     */
    function supplyLiquidity(uint256 amount) external;
    
    /**
     * @dev Borrows debt from the lending pool
     * @param amount Amount to borrow
     * @param _chainId Chain ID for cross-chain operations
     * @param _bridgeTokenSender Bridge token sender address
     * @notice This function allows users to borrow against their collateral
     * @custom:security Users must have sufficient collateral to borrow
     */
    function borrowDebt(uint256 amount, uint256 _chainId, uint256 _bridgeTokenSender) external payable;
    
    /**
     * @dev Repays debt using selected token
     * @param shares Number of shares to repay
     * @param _token Address of the token used for repayment
     * @param _fromPosition Whether to repay from position balance
     * @notice This function allows users to repay their borrowed debt
     * @custom:security Users must approve tokens before calling this function
     */
    function repayWithSelectedToken(uint256 shares, address _token, bool _fromPosition) external;
    
    /**
     * @dev Returns the total supply assets in the pool
     * @return Total amount of assets supplied to the pool
     */
    function totalSupplyAssets() external view returns (uint256);
    
    /**
     * @dev Returns the total supply shares in the pool
     * @return Total number of shares representing supplied assets
     */
    function totalSupplyShares() external view returns (uint256);
    
    /**
     * @dev Returns the total borrow shares in the pool
     * @return Total number of shares representing borrowed assets
     */
    function totalBorrowShares() external view returns (uint256);
    
    /**
     * @dev Returns the total borrow assets in the pool
     * @return Total amount of assets borrowed from the pool
     */
    function totalBorrowAssets() external view returns (uint256);
    
    /**
     * @dev Returns the timestamp of last interest accrual
     * @return Timestamp when interest was last accrued
     */
    function lastAccrued() external view returns (uint256);
    
    /**
     * @dev Returns the position address for a user
     * @param _user Address of the user
     * @return Address of the user's position contract
     */
    function addressPositions(address _user) external view returns (address);
    
    /**
     * @dev Swaps tokens within a user's position
     * @param _tokenFrom Address of the token to swap from
     * @param _tokenTo Address of the token to swap to
     * @param amountIn Amount of tokens to swap
     * @return amountOut Amount of tokens received from the swap
     * @notice This function allows users to swap tokens within their position
     * @custom:security Users must have sufficient balance of the token being swapped
     */
    function swapTokenByPosition(address _tokenFrom, address _tokenTo, uint256 amountIn)
        external
        returns (uint256 amountOut);
    
    /**
     * @dev Returns the borrow shares for a specific user
     * @param _user Address of the user
     * @return Number of borrow shares owned by the user
     */
    function userBorrowShares(address _user) external view returns (uint256);
}
