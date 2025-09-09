// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title InterestRateModel
 * @dev Dynamic interest rate model similar to Aave's implementation
 * @notice Calculates interest rates based on pool utilization using a multi-slope model
 * @author Ibran Team
 */
contract InterestRateModel is IInterestRateModel, Ownable {
    
    error InvalidParameter();
    error NotLendingPool();
    error LendingPoolAlreadySet();

    // Interest Rate Model Parameters (in basis points, 1% = 100)
    uint256 public baseRate;           // Base interest rate (minimum rate)
    uint256 public slope1;             // Rate increase when utilization is below optimal
    uint256 public slope2;             // Steep rate increase when utilization is above optimal
    uint256 public optimalUtilization; // Target utilization rate
    
    address public lendingPool;        // The lending pool that can update parameters

    /**
     * @notice Constructor to initialize the interest rate model
     * @param _owner The owner address for access control (factory owner)
     */
    constructor(address _owner) Ownable(_owner) {
        // Set default interest rate model parameters (similar to Aave)
        baseRate = 200;           // 2% base rate
        slope1 = 800;             // 8% slope below optimal
        slope2 = 6000;            // 60% slope above optimal
        optimalUtilization = 8000; // 80% optimal utilization
    }
    
    modifier onlyLendingPool() {
        if (msg.sender != lendingPool) revert NotLendingPool();
        _;
    }

    /**
     * @notice Calculate the current utilization rate of the pool.
     * @param totalSupplyAssets Total assets supplied to the pool
     * @param totalBorrowAssets Total assets borrowed from the pool
     * @return utilizationRate The current utilization rate in basis points (10000 = 100%)
     */
    function getUtilizationRate(uint256 totalSupplyAssets, uint256 totalBorrowAssets) 
        external 
        pure 
        returns (uint256 utilizationRate) 
    {
        if (totalSupplyAssets == 0) {
            return 0;
        }
        return (totalBorrowAssets * 10000) / totalSupplyAssets;
    }
    
    /**
     * @notice Calculate the current borrow interest rate based on utilization.
     * @param totalSupplyAssets Total assets supplied to the pool
     * @param totalBorrowAssets Total assets borrowed from the pool
     * @return borrowRate The current borrow interest rate in basis points per year
     */
    function getBorrowRate(uint256 totalSupplyAssets, uint256 totalBorrowAssets) 
        external 
        view 
        returns (uint256 borrowRate) 
    {
        uint256 utilizationRate = this.getUtilizationRate(totalSupplyAssets, totalBorrowAssets);
        
        if (utilizationRate <= optimalUtilization) {
            // Rate = baseRate + (utilization / optimal) * slope1
            return baseRate + (utilizationRate * slope1) / optimalUtilization;
        } else {
            // Rate = baseRate + slope1 + ((utilization - optimal) / (1 - optimal)) * slope2
            uint256 excessUtilization = utilizationRate - optimalUtilization;
            uint256 excessUtilizationRate = (excessUtilization * 10000) / (10000 - optimalUtilization);
            return baseRate + slope1 + (excessUtilizationRate * slope2) / 10000;
        }
    }
    
    /**
     * @notice Calculate the current supply interest rate.
     * @param totalSupplyAssets Total assets supplied to the pool
     * @param totalBorrowAssets Total assets borrowed from the pool
     * @return supplyRate The current supply interest rate in basis points per year
     */
    function getSupplyRate(uint256 totalSupplyAssets, uint256 totalBorrowAssets) 
        external 
        view 
        returns (uint256 supplyRate) 
    {
        uint256 borrowRate = this.getBorrowRate(totalSupplyAssets, totalBorrowAssets);
        uint256 utilizationRate = this.getUtilizationRate(totalSupplyAssets, totalBorrowAssets);
        
        // Assuming 10% reserve factor (1000 basis points)
        uint256 reserveFactor = 1000;
        
        return (borrowRate * utilizationRate * (10000 - reserveFactor)) / (10000 * 10000);
    }
    
    /**
     * @notice Set the lending pool address that can update parameters
     * @param _lendingPool The address of the lending pool
     * @dev Only the owner (factory) can set this, and only once
     */
    function setLendingPool(address _lendingPool) external onlyOwner {
        if (lendingPool != address(0)) revert LendingPoolAlreadySet();
        lendingPool = _lendingPool;
        emit LendingPoolSet(_lendingPool);
    }
    
    /**
     * @notice Automatically adjust interest rate model parameters based on pool state.
     * @param totalSupplyAssets Current total supply assets in the pool
     * @param totalBorrowAssets Current total borrow assets in the pool
     * @dev Only the lending pool can trigger auto-adjustment
     * @dev Automatically optimizes rates based on utilization, pool size, and market conditions
     */
    function autoAdjustInterestRateModel(
        uint256 totalSupplyAssets,
        uint256 totalBorrowAssets
    ) external onlyLendingPool {
        // Calculate current utilization rate
        uint256 currentUtilization = totalSupplyAssets == 0 ? 0 : (totalBorrowAssets * 10000) / totalSupplyAssets;
        
        // Auto-adjust parameters based on current pool state
        (uint256 newBaseRate, uint256 newSlope1, uint256 newSlope2, uint256 newOptimalUtilization) = 
            _calculateOptimalParameters(currentUtilization, totalSupplyAssets, totalBorrowAssets);
        
        // Update parameters
        baseRate = newBaseRate;
        slope1 = newSlope1;
        slope2 = newSlope2;
        optimalUtilization = newOptimalUtilization;
        
        emit InterestRateModelUpdated(newBaseRate, newSlope1, newSlope2, newOptimalUtilization);
    }
    
    /**
     * @notice Manual update of interest rate model parameters (for admin use).
     * @param _baseRate New base interest rate in basis points
     * @param _slope1 New slope1 parameter in basis points
     * @param _slope2 New slope2 parameter in basis points
     * @param _optimalUtilization New optimal utilization rate in basis points
     * @dev Only the owner can manually update parameters
     */
    function updateInterestRateModelManual(
        uint256 _baseRate,
        uint256 _slope1,
        uint256 _slope2,
        uint256 _optimalUtilization
    ) external onlyOwner {
        // Validate parameters
        if (_optimalUtilization > 10000) revert InvalidParameter(); // Max 100%
        if (_baseRate > 5000) revert InvalidParameter(); // Max 50% base rate
        if (_slope1 > 10000) revert InvalidParameter(); // Max 100% slope1
        if (_slope2 > 20000) revert InvalidParameter(); // Max 200% slope2
        
        baseRate = _baseRate;
        slope1 = _slope1;
        slope2 = _slope2;
        optimalUtilization = _optimalUtilization;
        
        emit InterestRateModelUpdated(_baseRate, _slope1, _slope2, _optimalUtilization);
    }
    
    /**
     * @notice Calculate optimal interest rate parameters based on pool metrics
     * @param currentUtilization Current utilization rate in basis points
     * @param totalSupplyAssets Total supply assets for pool size consideration
     * @param totalBorrowAssets Total borrow assets for market activity consideration
     * @return newBaseRate Calculated optimal base rate
     * @return newSlope1 Calculated optimal slope1
     * @return newSlope2 Calculated optimal slope2  
     * @return newOptimalUtilization Calculated optimal utilization target
     */
    function _calculateOptimalParameters(
        uint256 currentUtilization,
        uint256 totalSupplyAssets,
        uint256 totalBorrowAssets
    ) internal view returns (
        uint256 newBaseRate,
        uint256 newSlope1,
        uint256 newSlope2,
        uint256 newOptimalUtilization
    ) {
        // Base case: start with current parameters
        newBaseRate = baseRate;
        newSlope1 = slope1;
        newSlope2 = slope2;
        newOptimalUtilization = optimalUtilization;
        
        // Auto-adjustment logic based on utilization trends
        if (currentUtilization > 9000) {
            // Very high utilization (>90%) - encourage more supply, discourage borrowing
            newBaseRate = baseRate + 50;  // Increase base rate by 0.5%
            newSlope1 = slope1 + 100;     // Increase slope1 by 1%
            newSlope2 = slope2 + 500;     // Increase slope2 by 5%
        } else if (currentUtilization > 8500) {
            // High utilization (85-90%) - moderate adjustment
            newBaseRate = baseRate + 25;  // Increase base rate by 0.25%
            newSlope1 = slope1 + 50;      // Increase slope1 by 0.5%
            newSlope2 = slope2 + 200;     // Increase slope2 by 2%
        } else if (currentUtilization < 5000) {
            // Low utilization (<50%) - encourage borrowing
            newBaseRate = baseRate > 50 ? baseRate - 25 : baseRate;  // Decrease base rate
            newSlope1 = slope1 > 50 ? slope1 - 50 : slope1;          // Decrease slope1
            newOptimalUtilization = 8500; // Target higher utilization
        } else if (currentUtilization < 7000) {
            // Medium-low utilization (50-70%) - slight encouragement
            newBaseRate = baseRate > 25 ? baseRate - 10 : baseRate;  // Small decrease
            newOptimalUtilization = 8200; // Slightly higher target
        }
        
        // Pool size considerations
        if (totalSupplyAssets > 1000000 * 1e18) {
            // Large pool (>1M tokens) - can be more stable
            newSlope2 = newSlope2 > 1000 ? newSlope2 - 500 : newSlope2; // Less aggressive slope2
        } else if (totalSupplyAssets < 10000 * 1e18) {
            // Small pool (<10K tokens) - needs higher incentives
            newBaseRate = newBaseRate + 25; // Higher base rate for small pools
        }
        
        // Ensure parameters stay within bounds
        newBaseRate = newBaseRate > 1000 ? 1000 : newBaseRate;              // Max 10% base
        newSlope1 = newSlope1 > 2000 ? 2000 : newSlope1;                    // Max 20% slope1
        newSlope2 = newSlope2 > 15000 ? 15000 : newSlope2;                  // Max 150% slope2
        newOptimalUtilization = newOptimalUtilization > 9500 ? 9500 : newOptimalUtilization; // Max 95%
        newOptimalUtilization = newOptimalUtilization < 6000 ? 6000 : newOptimalUtilization; // Min 60%
    }
    
    /**
     * @notice Get current interest rate model parameters.
     * @return _baseRate Current base rate in basis points
     * @return _slope1 Current slope1 in basis points
     * @return _slope2 Current slope2 in basis points
     * @return _optimalUtilization Current optimal utilization in basis points
     */
    function getInterestRateModel() external view returns (
        uint256 _baseRate,
        uint256 _slope1,
        uint256 _slope2,
        uint256 _optimalUtilization
    ) {
        return (baseRate, slope1, slope2, optimalUtilization);
    }

}
