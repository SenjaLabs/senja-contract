// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ILendingPool
 * @notice Interface for lending pool functionality
 * @dev Defines the core lending pool operations including supply, borrow, and repay
 * @author Senja Labs
 * @custom:version 1.0.0
 */
interface ILendingPool {
    /**
     * @notice Returns the address of the lending pool router
     * @return Address of the router contract
     */
    function router() external view returns (address);

    /**
     * @notice Supplies collateral to the lending pool
     * @param _user Address of the user to supply collateral for
     * @param _amount Amount of collateral to supply
     * @dev Users must approve tokens before calling this function
     */
    function supplyCollateral(address _user, uint256 _amount) external payable;

    /**
     * @notice Supplies liquidity to the lending pool
     * @param _user Address of the user to supply liquidity for
     * @param _amount Amount of liquidity to supply
     * @dev Users must approve tokens before calling this function. Liquidity providers earn interest from borrowers.
     */
    function supplyLiquidity(address _user, uint256 _amount) external payable;

    /**
     * @notice Borrows debt from the lending pool
     * @param _amount Amount to borrow
     * @param _chainId Chain ID for cross-chain operations
     * @param _addExecutorLzReceiveOption Executor options for LayerZero messaging
     * @dev Users must have sufficient collateral to borrow. Cross-chain borrowing uses LayerZero.
     */
    function borrowDebt(uint256 _amount, uint256 _chainId, uint128 _addExecutorLzReceiveOption) external payable;

    /**
     * @notice Repays debt using selected token
     * @param _user Address of the user repaying the debt
     * @param _token Address of the token used for repayment
     * @param _shares Number of borrow shares to repay
     * @param _amountOutMinimum Minimum amount of borrow token expected from swap
     * @param _fromPosition Whether to repay from position balance or user wallet
     * @dev Users must approve tokens before calling this function. If token differs from borrow token, it will be swapped.
     */
    function repayWithSelectedToken(
        address _user,
        address _token,
        uint256 _shares,
        uint256 _amountOutMinimum,
        bool _fromPosition
    ) external payable;

    /**
     * @notice Withdraws supplied liquidity by redeeming shares
     * @param _shares Number of shares to redeem for underlying tokens
     * @dev Users must have sufficient shares to withdraw
     */
    function withdrawLiquidity(uint256 _shares) external payable;

    /**
     * @notice Withdraws supplied collateral from the user's position
     * @param _amount Amount of collateral to withdraw
     * @dev Users must have sufficient collateral and maintain healthy positions after withdrawal
     */
    function withdrawCollateral(uint256 _amount) external;

    /**
     * @notice Liquidates an unhealthy position
     * @param borrower The address of the borrower to liquidate
     * @dev Anyone can call this function to liquidate unhealthy positions and receive liquidation bonus
     */
    function liquidation(address borrower) external;

    /**
     * @notice Swaps tokens within a position
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param amountIn Amount of input tokens to swap
     * @param slippageTolerance Slippage tolerance for the swap (in basis points)
     * @return amountOut Amount of output tokens received
     * @dev Allows users to rebalance their collateral by swapping tokens within their position
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        external
        returns (uint256 amountOut);
}
