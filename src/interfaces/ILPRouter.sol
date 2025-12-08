// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ILPRouter
 * @notice Interface for lending pool router functionality
 * @dev Manages lending pool operations including supply, borrow, and liquidation
 */
interface ILPRouter {
    // ** READ FUNCTIONS **

    /// @notice Returns the total assets supplied to the lending pool
    function totalSupplyAssets() external view returns (uint256);

    /// @notice Returns the total shares representing supplied assets
    function totalSupplyShares() external view returns (uint256);

    /// @notice Returns the total assets borrowed from the lending pool
    function totalBorrowAssets() external view returns (uint256);

    /// @notice Returns the total shares representing borrowed assets
    function totalBorrowShares() external view returns (uint256);

    /// @notice Returns the timestamp of the last interest accrual
    function lastAccrued() external view returns (uint256);

    /**
     * @notice Returns the supply shares for a specific user
     * @param _user Address of the user
     * @return Number of supply shares owned by the user
     */
    function userSupplyShares(address _user) external view returns (uint256);

    /**
     * @notice Returns the borrow shares for a specific user
     * @param _user Address of the user
     * @return Number of borrow shares owned by the user
     */
    function userBorrowShares(address _user) external view returns (uint256);

    /**
     * @notice Returns the position contract address for a user
     * @param _user Address of the user
     * @return Address of the user's position contract
     */
    function addressPositions(address _user) external view returns (address);

    /// @notice Returns the address of the associated lending pool
    function lendingPool() external view returns (address);

    /// @notice Returns the address of the collateral token
    function collateralToken() external view returns (address);

    /// @notice Returns the address of the borrow token
    function borrowToken() external view returns (address);

    /// @notice Returns the loan-to-value ratio
    function ltv() external view returns (uint256);

    /// @notice Returns the address of the factory contract
    function factory() external view returns (address);

    /// @notice Returns the total reserve assets in the pool
    function totalReserveAssets() external view returns (uint256);

    // ** WRITE FUNCTIONS **

    /**
     * @notice Sets the lending pool address
     * @param _lendingPool Address of the lending pool
     */
    function setLendingPool(address _lendingPool) external;

    /**
     * @notice Supplies liquidity to the lending pool
     * @param _amount Amount of tokens to supply
     * @param _user Address of the user supplying liquidity
     * @return shares Number of shares minted to the user
     */
    function supplyLiquidity(uint256 _amount, address _user) external returns (uint256 shares);

    /**
     * @notice Withdraws liquidity from the lending pool
     * @param _shares Number of shares to redeem
     * @param _user Address of the user withdrawing liquidity
     * @return amount Amount of tokens withdrawn
     */
    function withdrawLiquidity(uint256 _shares, address _user) external returns (uint256 amount);

    /**
     * @notice Accrues interest for the lending pool
     * @dev Updates total borrow assets based on elapsed time and interest rate
     */
    function accrueInterest() external;

    /**
     * @notice Borrows debt from the lending pool
     * @param _amount Amount to borrow
     * @param _user Address of the borrower
     * @return protocolFee Fee taken by the protocol
     * @return userAmount Amount received by the user after fees
     * @return shares Number of borrow shares minted
     */
    function borrowDebt(uint256 _amount, address _user)
        external
        returns (uint256 protocolFee, uint256 userAmount, uint256 shares);

    /**
     * @notice Repays debt using selected token
     * @param _shares Number of shares to repay
     * @param _user Address of the user repaying
     * @return Amount values related to repayment (implementation specific)
     */
    function repayWithSelectedToken(uint256 _shares, address _user)
        external
        returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Creates a position contract for a user
     * @param _user Address of the user
     * @return Address of the newly created position contract
     */
    function createPosition(address _user) external returns (address);

    // ** LIQUIDATION FUNCTIONS **

    /**
     * @notice Liquidates an unhealthy borrowing position
     * @param _borrower Address of the borrower to liquidate
     * @return userBorrowAssets Total borrow assets of the user
     * @return liquidationBonus Liquidation bonus allocation
     * @return userPosition Address of the user's position contract
     */
    function liquidation(address _borrower)
        external
        returns (uint256 userBorrowAssets, uint256 liquidationBonus, address userPosition);
}
