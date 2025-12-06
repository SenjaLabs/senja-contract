// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {OFTadapter} from "./layerzero/OFTadapter.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {ITokenDataStream} from "./interfaces/ITokenDataStream.sol";

/**
 * @title HelperUtils
 * @notice Utility contract providing helper functions for lending pool calculations and queries
 * @dev Aggregates data from lending pools, positions, oracles, and provides various metrics
 */
contract HelperUtils {
    using OptionsBuilder for bytes;

    /// @notice Address of the factory contract
    address public factory;

    /**
     * @notice Constructs the HelperUtils contract
     * @param _factory Address of the factory contract
     */
    constructor(address _factory) {
        factory = _factory;
    }

    /**
     * @notice Sets the factory contract address
     * @param _factory New factory contract address
     */
    function setFactory(address _factory) public {
        factory = _factory;
    }

    /**
     * @notice Calculates the maximum amount a user can borrow from a lending pool
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return Maximum borrow amount available (limited by collateral and pool liquidity)
     * @dev Returns the minimum of: user's borrowing capacity based on collateral and LTV, or pool's available liquidity
     */
    function getMaxBorrowAmount(address _lendingPool, address _user) public view returns (uint256) {
        address borrowToken = _borrowToken(_lendingPool);
        uint256 totalLiquidity;

        if (borrowToken == _WRAPPED_NATIVE()) {
            // Handle Wrapped Native token
            totalLiquidity = IERC20(_WRAPPED_NATIVE()).balanceOf(_lendingPool);
        } else {
            // Handle ERC20 tokens
            totalLiquidity = IERC20(borrowToken).balanceOf(_lendingPool);
        }

        uint256 tokenValue = _calculateCollateralValue(_lendingPool, _user);
        uint256 borrowAmount = _calculateCurrentBorrowAmount(_lendingPool, _user);
        uint256 maxBorrowAmount = ((tokenValue * _ltv(_lendingPool)) / 1e18) - borrowAmount;
        return maxBorrowAmount < totalLiquidity ? maxBorrowAmount : totalLiquidity;
    }

    /**
     * @notice Calculates the exchange rate between two tokens
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _amountIn Amount of input token
     * @param _position Address of the position contract for calculation
     * @return Exchange rate value
     * @dev Uses oracle prices to calculate conversion rate
     */
    function getExchangeRate(address _tokenIn, address _tokenOut, uint256 _amountIn, address _position)
        public
        view
        returns (uint256)
    {
        address _tokenInPrice = _oracleAddress(_tokenIn);
        address _tokenOutPrice = _oracleAddress(_tokenOut);
        uint256 tokenValue =
            IPosition(_position).tokenCalculator(_tokenIn, _tokenOut, _amountIn, _tokenInPrice, _tokenOutPrice);

        return tokenValue;
    }

    /**
     * @notice Gets the current price of a token from the oracle
     * @param _token Address of the token
     * @return Current price of the token
     */
    function getTokenValue(address _token) public view returns (uint256) {
        address oracleAddress = _oracleAddress(_token);
        (, uint256 tokenPrice,,,) = IOracle(oracleAddress).latestRoundData();
        return uint256(tokenPrice);
    }

    /**
     * @notice Calculates the health factor of a user's position
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return Health factor value (>1e8 is healthy, <1e8 is at risk of liquidation)
     * @dev Health Factor = (Collateral Value * LTV) / Borrowed Value
     */
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

            if (token == _WRAPPED_NATIVE()) {
                // Handle Wrapped Native token
                tokenBalance = IERC20(_WRAPPED_NATIVE()).balanceOf(userPosition);
                tokenDecimals = 18; // Wrapped Native uses 18 decimals
            } else {
                // Handle ERC20 tokens
                tokenBalance = IERC20(token).balanceOf(userPosition);
                tokenDecimals = IERC20Metadata(token).decimals();
            }

            if (token != address(0)) {
                // Include all tokens including Wrapped Native
                collateralValue += (getTokenValue(token) * tokenBalance / 10 ** tokenDecimals);
            }
        }

        // Calculate borrowed value
        uint256 borrowAssets = ((userBorrowShares * totalBorrowAssets) / totalBorrowShares);
        uint256 borrowDecimals = borrowToken == _WRAPPED_NATIVE() ? 18 : IERC20Metadata(borrowToken).decimals();
        uint256 borrowValue = getTokenValue(borrowToken) * borrowAssets / 10 ** borrowDecimals;
        // Health Factor = (Collateral Value * LTV) / Borrowed Value
        uint256 ltv = _ltv(_lendingPool);
        uint256 healthFactor = (collateralValue * (ltv * 1e8 / 1e18)) / (borrowValue);
        return healthFactor; // >1e8 is healthy, <1e8 is unhealthy
    }

    /**
     * @notice Calculates the LayerZero messaging fee for a cross-chain token transfer
     * @param _oftAddress Address of the OFT adapter
     * @param _dstEid Destination endpoint ID
     * @param _toAddress Recipient address on destination chain
     * @param _tokensToSend Amount of tokens to send
     * @return Native fee required for the cross-chain transfer
     */
    function getFee(address _oftAddress, uint32 _dstEid, address _toAddress, uint256 _tokensToSend)
        public
        view
        returns (uint256)
    {
        OFTadapter oft = OFTadapter(_oftAddress);
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

    /**
     * @notice Get the supply APY (Annual Percentage Yield) for a lending pool
     * @param _lendingPool The address of the lending pool
     * @return supplyAPY The supply APY scaled by 1e18 (e.g., 5% = 5e16)
     * @dev APY accounts for daily compounding: APY = (1 + rate/365)^365 - 1
     */
    function getSupplyAPY(address _lendingPool) public view returns (uint256 supplyAPY) {
        ILPRouter router = _router(_lendingPool);
        uint256 supplyRate = router.calculateSupplyRate(); // Rate scaled by 100 (e.g., 500 = 5%)

        if (supplyRate == 0) {
            return 0;
        }

        // Convert rate from percentage to decimal: supplyRate / 10000
        // Then calculate daily rate: rate / 365
        // APY = (1 + dailyRate)^365 - 1
        // Using approximation for gas efficiency: APY ≈ rate + (rate^2 / 2) for small rates

        uint256 rateDecimal = (supplyRate * 1e18) / 10000; // Convert to 1e18 scale
        uint256 compoundEffect = (rateDecimal * rateDecimal) / (2 * 1e18); // rate^2 / 2
        supplyAPY = rateDecimal + compoundEffect;

        return supplyAPY;
    }

    /**
     * @notice Get the borrow APY (Annual Percentage Yield) for a lending pool
     * @param _lendingPool The address of the lending pool
     * @return borrowAPY The borrow APY scaled by 1e18 (e.g., 10% = 1e17)
     * @dev APY accounts for daily compounding: APY = (1 + rate/365)^365 - 1
     */
    function getBorrowAPY(address _lendingPool) public view returns (uint256 borrowAPY) {
        ILPRouter router = _router(_lendingPool);
        uint256 borrowRate = router.calculateBorrowRate(); // Rate scaled by 100 (e.g., 1000 = 10%)

        if (borrowRate == 0) {
            return 0;
        }

        // Convert rate from percentage to decimal: borrowRate / 10000
        // Then calculate APY with compounding effect
        uint256 rateDecimal = (borrowRate * 1e18) / 10000; // Convert to 1e18 scale
        uint256 compoundEffect = (rateDecimal * rateDecimal) / (2 * 1e18); // rate^2 / 2
        borrowAPY = rateDecimal + compoundEffect;

        return borrowAPY;
    }

    /**
     * @notice Get both supply and borrow APY for a lending pool
     * @param _lendingPool The address of the lending pool
     * @return supplyAPY The supply APY scaled by 1e18
     * @return borrowAPY The borrow APY scaled by 1e18
     * @return utilizationRate The utilization rate scaled by 1e18
     */
    function getAPY(address _lendingPool)
        public
        view
        returns (uint256 supplyAPY, uint256 borrowAPY, uint256 utilizationRate)
    {
        supplyAPY = getSupplyAPY(_lendingPool);
        borrowAPY = getBorrowAPY(_lendingPool);
        utilizationRate = getUtilizationRate(_lendingPool);

        return (supplyAPY, borrowAPY, utilizationRate);
    }

    /**
     * @notice Get the utilization rate for a lending pool
     * @param _lendingPool The address of the lending pool
     * @return utilizationRate The utilization rate scaled by 1e18 (e.g., 80% = 8e17)
     */
    function getUtilizationRate(address _lendingPool) public view returns (uint256 utilizationRate) {
        ILPRouter router = _router(_lendingPool);
        uint256 utilization = router.getUtilizationRate(); // Rate scaled by 10000 (e.g., 8000 = 80%)

        // Convert from 10000 scale to 1e18 scale
        utilizationRate = (utilization * 1e18) / 10000;

        return utilizationRate;
    }

    /**
     * @notice Get detailed lending pool metrics
     * @param _lendingPool The address of the lending pool
     * @return supplyAPY The supply APY scaled by 1e18
     * @return borrowAPY The borrow APY scaled by 1e18
     * @return utilizationRate The utilization rate scaled by 1e18
     * @return totalSupplyAssets Total supply assets in the pool
     * @return totalBorrowAssets Total borrow assets in the pool
     */
    function getLendingPoolMetrics(address _lendingPool)
        public
        view
        returns (
            uint256 supplyAPY,
            uint256 borrowAPY,
            uint256 utilizationRate,
            uint256 totalSupplyAssets,
            uint256 totalBorrowAssets
        )
    {
        ILPRouter router = _router(_lendingPool);

        supplyAPY = getSupplyAPY(_lendingPool);
        borrowAPY = getBorrowAPY(_lendingPool);
        utilizationRate = getUtilizationRate(_lendingPool);
        totalSupplyAssets = router.totalSupplyAssets();
        totalBorrowAssets = router.totalBorrowAssets();

        return (supplyAPY, borrowAPY, utilizationRate, totalSupplyAssets, totalBorrowAssets);
    }

    /**
     * @notice Gets the total available liquidity in a lending pool
     * @param _lendingPool Address of the lending pool
     * @return totalLiquidity Available liquidity amount
     */
    function getTotalLiquidity(address _lendingPool) public view returns (uint256 totalLiquidity) {
        address borrowToken = ILPRouter(_router(_lendingPool)).borrowToken();
        if (borrowToken == address(1)) {
            totalLiquidity = IERC20(_WRAPPED_NATIVE()).balanceOf(_lendingPool);
        } else {
            totalLiquidity = IERC20(borrowToken).balanceOf(_lendingPool);
        }
        return totalLiquidity;
    }

    /**
     * @notice Gets the collateral balance of a user in a lending pool
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return collateralBalance User's collateral balance
     */
    function getCollateralBalance(address _lendingPool, address _user) public view returns (uint256 collateralBalance) {
        address collateralToken = ILPRouter(_router(_lendingPool)).collateralToken();
        address addressPosition = ILPRouter(_router(_lendingPool)).addressPositions(_user);
        if (collateralToken == address(1)) {
            collateralBalance = IERC20(_WRAPPED_NATIVE()).balanceOf(addressPosition);
        } else {
            collateralBalance = IERC20(collateralToken).balanceOf(addressPosition);
        }
        return collateralBalance;
    }

    /**
     * @notice Gets the router address for a lending pool
     * @param _lendingPool Address of the lending pool
     * @return Address of the lending pool router
     */
    function getRouter(address _lendingPool) public view returns (address) {
        return ILendingPool(_lendingPool).router();
    }

    /**
     * @notice Internal function to calculate the total value of user's collateral
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return Total collateral value in borrow token terms
     */
    function _calculateCollateralValue(address _lendingPool, address _user) internal view returns (uint256) {
        address collateralToken = _collateralToken(_lendingPool);
        address borrowToken = _borrowToken(_lendingPool);
        address addressPosition = _addressPositions(_lendingPool, _user);

        address _tokenInPrice = _oracleAddress(collateralToken);
        address _tokenOutPrice = _oracleAddress(borrowToken);

        uint256 collateralBalance;
        if (collateralToken == _WRAPPED_NATIVE()) {
            // Handle Wrapped Native token
            collateralBalance = IERC20(_WRAPPED_NATIVE()).balanceOf(addressPosition);
        } else {
            // Handle ERC20 tokens
            collateralBalance = IERC20(collateralToken).balanceOf(addressPosition);
        }

        IPosition position = IPosition(addressPosition);
        return position.tokenCalculator(collateralToken, borrowToken, collateralBalance, _tokenInPrice, _tokenOutPrice);
    }

    /**
     * @notice Internal function to calculate user's current borrow amount
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return Current borrow amount based on user's shares
     */
    function _calculateCurrentBorrowAmount(address _lendingPool, address _user) internal view returns (uint256) {
        uint256 totalBorrowAssets = _totalBorrowAssets(_lendingPool);
        uint256 totalBorrowShares = _totalBorrowShares(_lendingPool);
        uint256 userBorrowShares = _userBorrowShares(_lendingPool, _user);

        return totalBorrowAssets == 0 ? 0 : (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
    }

    /**
     * @notice Internal function to get the router interface
     * @param _lendingPool Address of the lending pool
     * @return ILPRouter interface
     */
    function _router(address _lendingPool) internal view returns (ILPRouter) {
        return ILPRouter(ILendingPool(_lendingPool).router());
    }

    /**
     * @notice Internal function to get the borrow token address
     * @param _lendingPool Address of the lending pool
     * @return Address of the borrow token
     */
    function _borrowToken(address _lendingPool) internal view returns (address) {
        return _router(_lendingPool).borrowToken();
    }

    /**
     * @notice Internal function to get the collateral token address
     * @param _lendingPool Address of the lending pool
     * @return Address of the collateral token
     */
    function _collateralToken(address _lendingPool) internal view returns (address) {
        return _router(_lendingPool).collateralToken();
    }

    /**
     * @notice Internal function to get the loan-to-value ratio
     * @param _lendingPool Address of the lending pool
     * @return LTV ratio
     */
    function _ltv(address _lendingPool) internal view returns (uint256) {
        return _router(_lendingPool).ltv();
    }

    /**
     * @notice Internal function to get user's position address
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return Address of the user's position contract
     */
    function _addressPositions(address _lendingPool, address _user) internal view returns (address) {
        return _router(_lendingPool).addressPositions(_user);
    }

    /**
     * @notice Internal function to get total borrow assets in the pool
     * @param _lendingPool Address of the lending pool
     * @return Total borrow assets
     */
    function _totalBorrowAssets(address _lendingPool) internal view returns (uint256) {
        return _router(_lendingPool).totalBorrowAssets();
    }

    /**
     * @notice Internal function to get total borrow shares in the pool
     * @param _lendingPool Address of the lending pool
     * @return Total borrow shares
     */
    function _totalBorrowShares(address _lendingPool) internal view returns (uint256) {
        return _router(_lendingPool).totalBorrowShares();
    }

    /**
     * @notice Internal function to get user's borrow shares
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @return User's borrow shares
     */
    function _userBorrowShares(address _lendingPool, address _user) internal view returns (uint256) {
        return _router(_lendingPool).userBorrowShares(_user);
    }

    /**
     * @notice Internal function to get the token data stream address
     * @return Address of the token data stream contract
     */
    function _tokenDataStream() internal view returns (address) {
        return IFactory(factory).tokenDataStream();
    }

    /**
     * @notice Internal function to get the oracle address for a token
     * @param _token Address of the token
     * @return Address of the token's price feed oracle
     */
    function _oracleAddress(address _token) internal view returns (address) {
        return ITokenDataStream(_tokenDataStream()).tokenPriceFeed(_token);
    }

    /**
     * @notice Internal function to convert address to bytes32
     * @param _address Address to convert
     * @return bytes32 representation of the address
     */
    function _addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    /**
     * @notice Internal function to get the wrapped native token address
     * @return Address of the wrapped native token
     */
    function _WRAPPED_NATIVE() internal view returns (address) {
        return IFactory(factory).WRAPPED_NATIVE();
    }
}
