// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ILendingPool
 * @dev Interface for lending pool functionality
 * @notice This interface defines the core lending pool operations including supply, borrow, and repay
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface ILendingPool {
    function router() external view returns (address);

    /**
     * @dev Supplies collateral to the lending pool
     * @param _amount Amount of collateral to supply
     * @param _user Address of the user to supply collateral
     * @notice This function allows users to deposit collateral
     * @custom:security Users must approve tokens before calling this function
     */
    function supplyCollateral(address _user, uint256 _amount) external payable;

    /**
     * @dev Supplies liquidity to the lending pool
     * @param _user Address of the user to supply liquidity
     * @param _amount Amount of liquidity to supply
     * @notice This function allows users to provide liquidity for borrowing
     * @custom:security Users must approve tokens before calling this function
     */
    function supplyLiquidity(address _user, uint256 _amount) external payable;

    /**
     * @dev Borrows debt from the lending pool
     * @param _amount Amount to borrow
     * @param _chainId Chain ID for cross-chain operations
     * @param _addExecutorLzReceiveOption Executor options for LayerZero
     * @notice This function allows users to borrow against their collateral
     * @custom:security Users must have sufficient collateral to borrow
     */
    function borrowDebt(uint256 _amount, uint256 _chainId, uint128 _addExecutorLzReceiveOption)
        external
        payable;

    /**
     * @dev Repays debt using selected token
     * @param _shares Number of shares to repay
     * @param _token Address of the token used for repayment
     * @param _fromPosition Whether to repay from position balance
     * @param _user Address of the user repaying the debt
     * @param _amountOutMinimum Slippage tolerance in basis points (e.g., 500 = 5%)
     * @notice This function allows users to repay their borrowed debt
     * @custom:security Users must approve tokens before calling this function
     */
    function repayWithSelectedToken(
        address _user,
        address _token,
        uint256 _shares,
        uint256 _amountOutMinimum,
        bool _fromPosition
    ) external payable;

    /**
     * @dev Withdraws supplied liquidity by redeeming shares
     * @param _shares Number of shares to redeem for underlying tokens
     * @notice This function allows users to withdraw their supplied liquidity
     * @custom:security Users must have sufficient shares to withdraw
     */
    function withdrawLiquidity(uint256 _shares) external payable;

    /**
     * @dev Withdraws supplied collateral from the user's position
     * @param _amount Amount of collateral to withdraw
     * @notice This function allows users to withdraw their collateral
     * @custom:security Users must have sufficient collateral and maintain healthy positions
     */
    function withdrawCollateral(uint256 _amount) external;

    /**
     * @dev Liquidates an unhealthy position
     * @param borrower The address of the borrower to liquidate
     * @notice Anyone can call this function to liquidate unhealthy positions
     */
    function liquidation(address borrower) external;

    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        external
        returns (uint256 amountOut);
}
