// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title IIsHealthy
 * @dev Interface for health check functionality in lending pools
 * @notice This interface defines the contract for checking the health status of lending positions
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
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
}
