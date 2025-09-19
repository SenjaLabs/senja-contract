// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IIsHealthy
 * @dev Interface for health check functionality in lending pools
 * @notice This interface defines the contract for checking the health status of lending positions
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IIsHealthy {
    /**
     * @dev Checks if a lending position is healthy based on various parameters
     * @param borrowToken Address of the token being borrowed
     * @param factory Address of the lending pool factory
     * @param addressPositions Address of the positions contract
     * @param ltv Loan-to-value ratio for the position
     * @param totalBorrowAssets Total assets borrowed across all positions
     * @param totalBorrowShares Total shares representing borrowed assets
     * @param userBorrowShares User's specific borrow shares
     * @notice This function validates if a position meets health requirements
     * @custom:security This function should be called before allowing new borrows
     */
    function _isHealthy(
        address borrowToken,
        address factory,
        address addressPositions,
        uint256 ltv,
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 userBorrowShares
    ) external view;

    /**
     * @dev Returns the address of the liquidator contract
     * @return The address of the liquidator contract
     */
    function liquidator() external view returns (address);

    /**
     * @dev Checks if a position is liquidatable
     * @param borrowToken Address of the token being borrowed
     * @param factory Address of the lending pool factory
     * @param addressPositions Address of the positions contract
     * @param ltv Loan-to-value ratio for the position
     * @param totalBorrowAssets Total assets borrowed across all positions
     * @param totalBorrowShares Total shares representing borrowed assets
     * @param userBorrowShares User's specific borrow shares
     * @return isLiquidatable Whether the position can be liquidated
     * @return borrowValue The current borrow value in USD
     * @return collateralValue The current collateral value in USD
     */
    function checkLiquidation(
        address borrowToken,
        address factory,
        address addressPositions,
        uint256 ltv,
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 userBorrowShares
    ) external view returns (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue);

    /**
     * @dev Liquidates a position using DEX (DragonSwap)
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param factory The address of the factory
     * @param liquidationIncentive The liquidation incentive in basis points
     * @return liquidatedAmount Amount of debt repaid
     */
    function liquidateByDEX(
        address borrower,
        address lendingPoolRouter,
        address factory,
        uint256 liquidationIncentive
    ) external returns (uint256 liquidatedAmount);

    /**
     * @dev Liquidates a position using MEV (external liquidator buys collateral)
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param factory The address of the factory
     * @param repayAmount Amount of debt the liquidator wants to repay
     * @param liquidationIncentive The liquidation incentive in basis points
     */
    function liquidateByMEV(
        address borrower,
        address lendingPoolRouter,
        address factory,
        uint256 repayAmount,
        uint256 liquidationIncentive
    ) external payable;
}
