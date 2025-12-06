// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IInterestRateModel
 * @notice Interface for dynamic interest rate calculation
 * @dev Defines the contract for calculating dynamic interest rates based on utilization
 * @author Senja Team
 */
interface IInterestRateModel {
    /**
     * @notice Calculates the current borrow rate based on utilization
     * @param _lendingPool The lending pool address to calculate borrow rate for
     * @return borrowRate The annual borrow rate scaled by 100 (e.g., 500 = 5%)
     */
    function calculateBorrowRate(address _lendingPool) external view returns (uint256 borrowRate);

    /**
     * @notice Calculates interest accrued over a time period
     * @param _lendingPool The lending pool address to calculate interest for
     * @param _elapsedTime Time elapsed since last accrual in seconds
     * @return interest The interest amount accrued
     */
    function calculateInterest(address _lendingPool, uint256 _elapsedTime) external view returns (uint256 interest);

    /**
     * @notice Returns the maximum utilization rate for a lending pool
     * @param _lendingPool The lending pool address to query
     * @return maxUtilization The maximum utilization rate (in basis points)
     */
    function lendingPoolMaxUtilization(address _lendingPool) external view returns (uint256 maxUtilization);

    /**
     * @notice Sets the base interest rate for a lending pool
     * @param _lendingPool The lending pool address to configure
     * @param _baseRate The base interest rate when utilization is 0
     */
    function setLendingPoolBaseRate(address _lendingPool, uint256 _baseRate) external;

    /**
     * @notice Sets the interest rate at optimal utilization for a lending pool
     * @param _lendingPool The lending pool address to configure
     * @param _rateAtOptimal The interest rate at optimal utilization
     */
    function setLendingPoolRateAtOptimal(address _lendingPool, uint256 _rateAtOptimal) external;

    /**
     * @notice Sets the optimal utilization rate for a lending pool
     * @param _lendingPool The lending pool address to configure
     * @param _optimalUtilization The target optimal utilization rate (in basis points)
     */
    function setLendingPoolOptimalUtilization(address _lendingPool, uint256 _optimalUtilization) external;

    /**
     * @notice Sets the maximum utilization rate for a lending pool
     * @param _lendingPool The lending pool address to configure
     * @param _maxUtilization The maximum utilization rate allowed (in basis points)
     */
    function setLendingPoolMaxUtilization(address _lendingPool, uint256 _maxUtilization) external;
}
