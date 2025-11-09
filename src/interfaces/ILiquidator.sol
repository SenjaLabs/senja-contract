// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ILiquidator
 * @dev Interface for liquidation functionality
 * @notice This interface defines the contract for liquidating unhealthy positions
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface ILiquidator {
    /**
     * @dev Liquidates a position using DEX
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param factory The address of the factory
     * @param liquidationIncentive The liquidation incentive in basis points
     * @return liquidatedAmount Amount of debt repaid
     */
    function liquidateByDEX(address borrower, address lendingPoolRouter, address factory, uint256 liquidationIncentive)
        external
        returns (uint256 liquidatedAmount);

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
