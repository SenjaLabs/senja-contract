// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

contract HelperUtils {
    address public factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function setFactory(address _factory) public {
        factory = _factory;
    }

    function getMaxBorrowAmount(address _lendingPool, address _user) public view returns (uint256) {
        ILendingPool lendingPool = ILendingPool(_lendingPool);

        uint256 ltv = lendingPool.ltv();
        address borrowToken = lendingPool.borrowToken();
        uint256 totalLiquidity = IERC20(borrowToken).balanceOf(_lendingPool);

        // Calculate collateral value in a separate scope to reduce stack depth
        uint256 tokenValue = _calculateCollateralValue(lendingPool, _user);

        // Calculate current borrow amount in a separate scope
        uint256 borrowAmount = _calculateCurrentBorrowAmount(lendingPool, _user);

        uint256 maxBorrowAmount = ((tokenValue * ltv) / 1e18) - borrowAmount;

        return maxBorrowAmount < totalLiquidity ? maxBorrowAmount : totalLiquidity;
    }

    function _calculateCollateralValue(ILendingPool lendingPool, address _user) internal view returns (uint256) {
        address collateralToken = lendingPool.collateralToken();
        address borrowToken = lendingPool.borrowToken();
        address addressPosition = lendingPool.addressPositions(_user);

        address _tokenInPrice = IFactory(factory).tokenDataStream(collateralToken);
        address _tokenOutPrice = IFactory(factory).tokenDataStream(borrowToken);

        uint256 collateralBalance = IERC20(collateralToken).balanceOf(addressPosition);

        IPosition position = IPosition(addressPosition);
        return position.tokenCalculator(collateralToken, borrowToken, collateralBalance, _tokenInPrice, _tokenOutPrice);
    }

    function _calculateCurrentBorrowAmount(ILendingPool lendingPool, address _user) internal view returns (uint256) {
        uint256 totalBorrowAssets = lendingPool.totalBorrowAssets();
        uint256 totalBorrowShares = lendingPool.totalBorrowShares();
        uint256 userBorrowShares = lendingPool.userBorrowShares(_user);

        return totalBorrowAssets == 0 ? 0 : (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
    }

    function getExchangeRate(address _tokenIn, address _tokenOut, uint256 _amountIn, address _position)
        public
        view
        returns (uint256)
    {
        address _tokenInPrice = IFactory(factory).tokenDataStream(_tokenIn);
        address _tokenOutPrice = IFactory(factory).tokenDataStream(_tokenOut);
        uint256 tokenValue =
            IPosition(_position).tokenCalculator(_tokenIn, _tokenOut, _amountIn, _tokenInPrice, _tokenOutPrice);

        return tokenValue;
    }

    function getTokenValue(address _token) public view returns (uint256) {
        address tokenDataStream = IFactory(factory).tokenDataStream(_token);
        (, int256 tokenPrice,,,) = IPriceFeed(tokenDataStream).latestRoundData();
        return uint256(tokenPrice);
    }

    function getHealthFactor(address _lendingPool, address _user) public view returns (uint256) {
        ILendingPool lendingPool = ILendingPool(_lendingPool);

        // Get user's position and borrow data
        address userPosition = lendingPool.addressPositions(_user);
        uint256 userBorrowShares = lendingPool.userBorrowShares(_user);
        uint256 totalBorrowAssets = lendingPool.totalBorrowAssets();
        uint256 totalBorrowShares = lendingPool.totalBorrowShares();
        address borrowToken = lendingPool.borrowToken();

        if (userBorrowShares == 0) {
            return 69; // No debt = infinite health factor
        }
        if (userPosition == address(0)) {
            return 6969;
        }

        // Calculate collateral value (similar to IsHealthy contract)
        uint256 collateralValue = 0;
        uint256 counter = IPosition(userPosition).counter();
        for (uint256 i = 1; i <= counter; i++) {
            address token = IPosition(userPosition).tokenLists(i);
            uint256 tokenBalance = IERC20(token).balanceOf(userPosition);
            if (token != address(0)) {
                collateralValue += (getTokenValue(token) * tokenBalance / 10 ** IERC20Metadata(token).decimals());
            }
        }

        // Calculate borrowed value
        uint256 borrowAssets = ((userBorrowShares * totalBorrowAssets) / totalBorrowShares);
        uint256 borrowValue = getTokenValue(borrowToken) * borrowAssets / 10 ** IERC20Metadata(borrowToken).decimals();

        // Health Factor = (Collateral Value * LTV) / Borrowed Value
        uint256 ltv = lendingPool.ltv();
        uint256 healthFactor = (collateralValue * (ltv * 1e8 / 1e18)) / (borrowValue);

        return healthFactor; // >1e8 is healthy, <1e8 is unhealthy
    }
}
