// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {OFTAdapter} from "./layerzero/OFTAdapter.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract HelperUtils {
    using OptionsBuilder for bytes;

    address public factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function setFactory(address _factory) public {
        factory = _factory;
    }

    function getMaxBorrowAmount(address _lendingPool, address _user) public view returns (uint256) {
        address borrowToken = _borrowToken(_lendingPool);
        uint256 totalLiquidity;

        if (borrowToken == _WKAIA()) {
            // Handle WKAIA token
            totalLiquidity = IERC20(_WKAIA()).balanceOf(_lendingPool);
        } else {
            // Handle ERC20 tokens
            totalLiquidity = IERC20(borrowToken).balanceOf(_lendingPool);
        }

        uint256 tokenValue = _calculateCollateralValue(_lendingPool, _user);
        uint256 borrowAmount = _calculateCurrentBorrowAmount(_lendingPool, _user);
        uint256 maxBorrowAmount = ((tokenValue * _ltv(_lendingPool)) / 1e18) - borrowAmount;
        return maxBorrowAmount < totalLiquidity ? maxBorrowAmount : totalLiquidity;
    }

    function getExchangeRate(address _tokenIn, address _tokenOut, uint256 _amountIn, address _position)
        public
        view
        returns (uint256)
    {
        address _tokenInPrice = _tokenDataStream(_tokenIn);
        address _tokenOutPrice = _tokenDataStream(_tokenOut);
        uint256 tokenValue =
            IPosition(_position).tokenCalculator(_tokenIn, _tokenOut, _amountIn, _tokenInPrice, _tokenOutPrice);

        return tokenValue;
    }

    function getTokenValue(address _token) public view returns (uint256) {
        address tokenDataStream = _tokenDataStream(_token);
        (, uint256 tokenPrice,,,) = IOracle(tokenDataStream).latestRoundData();
        return uint256(tokenPrice);
    }

    function getHealthFactor(address _lendingPool, address _user) public view returns (uint256) {
        // Get user's position and borrow data
        address userPosition = _addressPositions(_lendingPool, _user);
        uint256 userBorrowShares = _userBorrowShares(_lendingPool, _user);
        uint256 totalBorrowAssets = _totalBorrowAssets(_lendingPool);
        uint256 totalBorrowShares = _totalBorrowShares(_lendingPool);
        address borrowToken = _borrowToken(_lendingPool);

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
            uint256 tokenBalance;
            uint256 tokenDecimals;

            if (token == _WKAIA()) {
                // Handle WKAIA token
                tokenBalance = IERC20(_WKAIA()).balanceOf(userPosition);
                tokenDecimals = 18; // WKAIA uses 18 decimals
            } else {
                // Handle ERC20 tokens
                tokenBalance = IERC20(token).balanceOf(userPosition);
                tokenDecimals = IERC20Metadata(token).decimals();
            }

            if (token != address(0)) {
                // Include all tokens including WKAIA
                collateralValue += (getTokenValue(token) * tokenBalance / 10 ** tokenDecimals);
            }
        }

        // Calculate borrowed value
        uint256 borrowAssets = ((userBorrowShares * totalBorrowAssets) / totalBorrowShares);
        uint256 borrowDecimals = borrowToken == _WKAIA() ? 18 : IERC20Metadata(borrowToken).decimals();
        uint256 borrowValue = getTokenValue(borrowToken) * borrowAssets / 10 ** borrowDecimals;
        // Health Factor = (Collateral Value * LTV) / Borrowed Value
        uint256 ltv = _ltv(_lendingPool);
        uint256 healthFactor = (collateralValue * (ltv * 1e8 / 1e18)) / (borrowValue);
        return healthFactor; // >1e8 is healthy, <1e8 is unhealthy
    }

    function _calculateCollateralValue(address _lendingPool, address _user) internal view returns (uint256) {
        address collateralToken = _collateralToken(_lendingPool);
        address borrowToken = _borrowToken(_lendingPool);
        address addressPosition = _addressPositions(_lendingPool, _user);

        address _tokenInPrice = _tokenDataStream(collateralToken);
        address _tokenOutPrice = _tokenDataStream(borrowToken);

        uint256 collateralBalance;
        if (collateralToken == _WKAIA()) {
            // Handle WKAIA token
            collateralBalance = IERC20(_WKAIA()).balanceOf(addressPosition);
        } else {
            // Handle ERC20 tokens
            collateralBalance = IERC20(collateralToken).balanceOf(addressPosition);
        }

        IPosition position = IPosition(addressPosition);
        return position.tokenCalculator(collateralToken, borrowToken, collateralBalance, _tokenInPrice, _tokenOutPrice);
    }

    function _calculateCurrentBorrowAmount(address _lendingPool, address _user) internal view returns (uint256) {
        uint256 totalBorrowAssets = _totalBorrowAssets(_lendingPool);
        uint256 totalBorrowShares = _totalBorrowShares(_lendingPool);
        uint256 userBorrowShares = _userBorrowShares(_lendingPool, _user);

        return totalBorrowAssets == 0 ? 0 : (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
    }

    function _router(address _lendingPool) internal view returns (ILPRouter) {
        return ILPRouter(ILendingPool(_lendingPool).router());
    }

    function _borrowToken(address _lendingPool) internal view returns (address) {
        return _router(_lendingPool).borrowToken();
    }

    function _collateralToken(address _lendingPool) internal view returns (address) {
        return _router(_lendingPool).collateralToken();
    }

    function _ltv(address _lendingPool) internal view returns (uint256) {
        return _router(_lendingPool).ltv();
    }

    function _addressPositions(address _lendingPool, address _user) internal view returns (address) {
        return _router(_lendingPool).addressPositions(_user);
    }

    function _totalBorrowAssets(address _lendingPool) internal view returns (uint256) {
        return _router(_lendingPool).totalBorrowAssets();
    }

    function _totalBorrowShares(address _lendingPool) internal view returns (uint256) {
        return _router(_lendingPool).totalBorrowShares();
    }

    function _userBorrowShares(address _lendingPool, address _user) internal view returns (uint256) {
        return _router(_lendingPool).userBorrowShares(_user);
    }

    function _tokenDataStream(address _token) internal view returns (address) {
        return IFactory(factory).tokenDataStream(_token);
    }

    function _addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    function _WKAIA() internal view returns (address) {
        return IFactory(factory).WKAIA();
    }

    function getFee(address _oftAddress, uint32 _dstEid, address _toAddress, uint256 _tokensToSend)
        public
        view
        returns (uint256)
    {
        OFTAdapter oft = OFTAdapter(_oftAddress);
        // Build send parameters
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: _addressToBytes32(_toAddress),
            amountLD: _tokensToSend,
            minAmountLD: _tokensToSend, // 0% slippage tolerance
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });

        // Get fee quote
        MessagingFee memory fee = oft.quoteSend(sendParam, false);

        return fee.nativeFee;
    }
}
