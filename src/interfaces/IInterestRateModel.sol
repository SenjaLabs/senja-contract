// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IInterestRateModel
 * @dev Interface for dynamic interest rate calculation
 * @notice This interface defines the contract for calculating dynamic interest rates based on utilization
 * @author Senja Team
 */
interface IInterestRateModel {
    /**
     * @notice Calculate the current utilization rate of the pool.
     * @param totalSupplyAssets Total assets supplied to the pool
     * @param totalBorrowAssets Total assets borrowed from the pool
     * @return utilizationRate The current utilization rate in basis points (10000 = 100%)
     */
    function getUtilizationRate(uint256 totalSupplyAssets, uint256 totalBorrowAssets)
        external
        view
        returns (uint256 utilizationRate);

    /**
     * @notice Calculate the current borrow interest rate based on utilization.
     * @param totalSupplyAssets Total assets supplied to the pool
     * @param totalBorrowAssets Total assets borrowed from the pool
     * @return borrowRate The current borrow interest rate in basis points per year
     */
    function getBorrowRate(uint256 totalSupplyAssets, uint256 totalBorrowAssets)
        external
        view
        returns (uint256 borrowRate);

    /**
     * @notice Calculate the current supply interest rate.
     * @param totalSupplyAssets Total assets supplied to the pool
     * @param totalBorrowAssets Total assets borrowed from the pool
     * @return supplyRate The current supply interest rate in basis points per year
     */
    function getSupplyRate(uint256 totalSupplyAssets, uint256 totalBorrowAssets)
        external
        view
        returns (uint256 supplyRate);

    /**
     * @notice Set the lending pool address that can update parameters
     * @param _lendingPool The address of the lending pool
     */
    function setLendingPool(address _lendingPool) external;

    /**
     * @notice Automatically adjust interest rate model parameters based on pool state.
     * @param totalSupplyAssets Current total supply assets in the pool
     * @param totalBorrowAssets Current total borrow assets in the pool
     */
    function autoAdjustInterestRateModel(uint256 totalSupplyAssets, uint256 totalBorrowAssets) external;

    /**
     * @notice Manual update of interest rate model parameters (for admin use).
     * @param _baseRate New base interest rate in basis points
     * @param _slope1 New slope1 parameter in basis points
     * @param _slope2 New slope2 parameter in basis points
     * @param _optimalUtilization New optimal utilization rate in basis points
     */
    function updateInterestRateModelManual(
        uint256 _baseRate,
        uint256 _slope1,
        uint256 _slope2,
        uint256 _optimalUtilization
    ) external;

    /**
     * @notice Get the lending pool address
     * @return lendingPool The address of the lending pool
     */
    function lendingPool() external view returns (address);

    /**
     * @notice Get current interest rate model parameters.
     * @return _baseRate Current base rate in basis points
     * @return _slope1 Current slope1 in basis points
     * @return _slope2 Current slope2 in basis points
     * @return _optimalUtilization Current optimal utilization in basis points
     */
    function getInterestRateModel()
        external
        view
        returns (uint256 _baseRate, uint256 _slope1, uint256 _slope2, uint256 _optimalUtilization);

    /**
     * @notice Event emitted when interest rate model parameters are updated
     */
    event InterestRateModelUpdated(uint256 baseRate, uint256 slope1, uint256 slope2, uint256 optimalUtilization);

    /**
     * @notice Event emitted when lending pool address is set
     */
    event LendingPoolSet(address indexed lendingPool);
}
