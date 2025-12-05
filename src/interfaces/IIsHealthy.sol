// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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

    function setLiquidationThreshold(address router, uint256 liquidationThreshold) external;

    function setLiquidationBonus(address router, uint256 liquidationBonus) external;
    function setFactory(address factory) external;
}
