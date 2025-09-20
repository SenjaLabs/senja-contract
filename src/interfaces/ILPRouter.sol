// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILPRouter {
    // ** READ
    function totalSupplyAssets() external view returns (uint256);
    function totalSupplyShares() external view returns (uint256);
    function totalBorrowAssets() external view returns (uint256);
    function totalBorrowShares() external view returns (uint256);
    function lastAccrued() external view returns (uint256);
    function userSupplyShares(address _user) external view returns (uint256);
    function userBorrowShares(address _user) external view returns (uint256);
    function userCollateral(address _user) external view returns (uint256);
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
    function supplyCollateral(address _user, uint256 _amount) external;
    function withdrawCollateral(uint256 _amount, address _user) external returns (uint256);
    function accrueInterest() external;
    function borrowDebt(uint256 _amount, address _user)
        external
        returns (uint256 protocolFee, uint256 userAmount, uint256 shares);
    function repayWithSelectedToken(uint256 _shares, address _user)
        external
        returns (uint256, uint256, uint256, uint256);
    function createPosition(address _user) external returns (address);

    // ** LIQUIDATION FUNCTIONS
    function liquidatePosition(address _user, uint256 _repayAmount) external;
    function emergencyResetPosition(address _user) external;
    function reduceUserCollateral(address _user, uint256 _amount) external;
}
