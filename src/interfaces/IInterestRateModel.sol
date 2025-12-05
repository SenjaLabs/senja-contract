// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IInterestRateModel
 * @dev Interface for dynamic interest rate calculation
 * @notice This interface defines the contract for calculating dynamic interest rates based on utilization
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

    function lendingPoolMaxUtilization(address _lendingPool) external view returns (uint256 maxUtilization);

    function setLendingPoolBaseRate(address _lendingPool, uint256 _baseRate) external;
    function setLendingPoolRateAtOptimal(address _lendingPool, uint256 _rateAtOptimal) external;
    function setLendingPoolOptimalUtilization(address _lendingPool, uint256 _optimalUtilization) external;
    function setLendingPoolMaxUtilization(address _lendingPool, uint256 _maxUtilization) external;
}
