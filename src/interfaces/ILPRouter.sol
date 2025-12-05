// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ILPRouter {
    // ** READ
    function totalSupplyAssets() external view returns (uint256);
    function totalSupplyShares() external view returns (uint256);
    function totalBorrowAssets() external view returns (uint256);
    function totalBorrowShares() external view returns (uint256);
    function lastAccrued() external view returns (uint256);
    function userSupplyShares(address _user) external view returns (uint256);
    function userBorrowShares(address _user) external view returns (uint256);
    function addressPositions(address _user) external view returns (address);
    function lendingPool() external view returns (address);
    function collateralToken() external view returns (address);
    function borrowToken() external view returns (address);
    function ltv() external view returns (uint256);
    function factory() external view returns (address);
    function calculateBorrowRate() external view returns (uint256);
    function getUtilizationRate() external view returns (uint256);
    function calculateSupplyRate() external view returns (uint256);

    // ** WRITE
    function setLendingPool(address _lendingPool) external;
    function supplyLiquidity(uint256 _amount, address _user) external returns (uint256 shares);
    function withdrawLiquidity(uint256 _shares, address _user) external returns (uint256 amount);
    function accrueInterest() external;
    function borrowDebt(uint256 _amount, address _user)
        external
        returns (uint256 protocolFee, uint256 userAmount, uint256 shares);
    function repayWithSelectedToken(uint256 _shares, address _user)
        external
        returns (uint256, uint256, uint256, uint256);
    function createPosition(address _user) external returns (address);

    // ** LIQUIDATION FUNCTIONS
    function liquidation(address _borrower)
        external
        returns (
            uint256 userBorrowAssets,
            uint256 borrowerCollateral,
            uint256 liquidationAllocation,
            uint256 collateralToLiquidator,
            address userPosition
        );
}
