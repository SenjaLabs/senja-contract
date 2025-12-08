// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IIsHealthy
 * @dev Interface for health check functionality in lending pools
 * @notice This interface defines the contract for checking the health status of lending positions
 * @author Senja Labs
 * @custom:version 1.0.0
 */
interface IIsHealthy {
    /// @notice Thrown when user tries to borrow more than allowed by LTV ratio
    /// @param borrowValue Total value user is trying to borrow
    /// @param maxBorrowValue Maximum borrow value allowed by LTV
    /// @param ltv The loan-to-value ratio (e.g., 0.6e18 = 60%)
    error ExceedsMaxLTV(uint256 borrowValue, uint256 maxBorrowValue, uint256 ltv);

    /// @notice Thrown when a position is at risk of liquidation (exceeds liquidation threshold)
    /// @param borrowValue Total value of borrowed assets
    /// @param maxCollateralValue Maximum collateral value at liquidation threshold
    /// @param liquidationThreshold The liquidation threshold (e.g., 0.85e18 = 85%)
    error LiquidationAlert(uint256 borrowValue, uint256 maxCollateralValue, uint256 liquidationThreshold);

    /**
     * @dev Checks if a lending position is healthy based on various parameters
     * @param user The address of the user to check
     * @param router The address of the lending pool router
     * @notice This function validates if a position meets health requirements
     * @custom:security This function should be called before allowing new borrows
     */
    function isHealthy(address user, address router) external view;

    /**
     * @dev Returns the address of the liquidator contract
     * @return The address of the liquidator contract
     */
    function liquidator() external view returns (address);

    /**
     * @dev Checks if a position is liquidatable
     * @param user The address of the user to check
     * @param router The address of the lending pool router
     * @return isLiquidatable Whether the position can be liquidated
     * @return borrowValue The current borrow value in USD
     * @return collateralValue The current collateral value in USD
     */
    function checkLiquidatable(address user, address router)
        external
        view
        returns (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue, uint256 liquidationAllocation);

    /**
     * @notice Sets the liquidation threshold for a lending pool
     * @param router The address of the lending pool router
     * @param liquidationThreshold The new liquidation threshold value
     */
    function setLiquidationThreshold(address router, uint256 liquidationThreshold) external;

    /**
     * @notice Sets the liquidation bonus for a lending pool
     * @param router The address of the lending pool router
     * @param liquidationBonus The new liquidation bonus value
     */
    function setLiquidationBonus(address router, uint256 liquidationBonus) external;

    /**
     * @notice Sets the factory address
     * @param factory The address of the factory contract
     */
    function setFactory(address factory) external;
}
