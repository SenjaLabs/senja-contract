// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ITokenDataStream} from "./interfaces/ITokenDataStream.sol";
import {IPosition} from "./interfaces/IPosition.sol";

/**
 * @title IsHealthy
 * @author Senja Protocol Team
 * @notice Contract that validates the health of borrowing positions based on collateral ratios
 * @dev This contract implements health checks for lending positions by comparing the value
 *      of a user's collateral against their borrowed amount and the loan-to-value (LTV) ratio.
 *      It prevents users from borrowing more than their collateral can safely support.
 *
 * Key Features:
 * - Multi-token collateral support across different chains
 * - Real-time price feed integration via TokenDataStream
 * - Configurable loan-to-value ratios per token
 * - Automatic liquidation threshold detection
 * - Precision handling for different token decimals
 */
contract IsHealthy is Ownable {
    // =============================================================
    //                           ERRORS
    // =============================================================

    /// @notice Thrown when an invalid loan-to-value ratio is provided (e.g., zero)
    /// @param ltv The invalid LTV ratio that was provided
    error InvalidLtv(address lendingPool, uint256 ltv);

    error ZeroCollateralAmount(address lendingPool, uint256 userCollateralAmount, uint256 totalCollateral);

    error LtvMustBeLessThanThreshold(address lendingPool, uint256 ltv, uint256 threshold);

    error LiquidationAlert(uint256 borrowValue, uint256 collateralValue);

    error LiquidationThresholdNotSet(address lendingPool);

    error LiquidationBonusNotSet(address lendingPool);

    error ZeroAddress();
    error NotFactory();

    event FactorySet(address factory);

    event LiquidationThresholdSet(address lendingPool, uint256 threshold);

    event LiquidationBonusSet(address lendingPool, uint256 bonus);

    event MaxLiquidationPercentageSet(uint256 percentage);

    // =============================================================
    //                       STATE VARIABLES
    // =============================================================

    /// @notice Address of the Factory contract for accessing protocol configurations
    address public factory;

    /// @notice Liquidation threshold for each collateral token (with 18 decimals precision)
    /// @dev lendingPool address => liquidation threshold (e.g., 0.85e18 = 85%)
    /// When health factor drops below this, position can be liquidated
    mapping(address => uint256) public liquidationThreshold;

    /// @notice Liquidation bonus for each collateral token (with 18 decimals precision)
    /// @dev router address => liquidation bonus (e.g., 0.05e18 = 5% bonus to liquidator)
    /// Liquidators receive collateral worth (debt repaid * (1 + bonus))
    mapping(address => uint256) public liquidationBonus;

    // =============================================================
    //                           CONSTRUCTOR
    // =============================================================

    /// @notice Initializes the IsHealthy contract with a factory address
    /// @dev Sets up Ownable with deployer as owner and configures the factory
    constructor() Ownable(msg.sender) {}

    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    // =============================================================
    //                        HEALTH CHECK FUNCTIONS
    // =============================================================

    /// @notice Validates whether a user's borrowing position is healthy
    /// @dev Calculates the total USD value of user's collateral across all supported tokens
    ///      and compares it against their borrowed amount and the liquidation threshold.
    ///      Reverts if the position is unhealthy (over-leveraged).
    /// @param _user The user address whose position is being checked
    /// @param _router The lending pool contract address
    function isHealthy(address _user, address _router) public view {
        uint256 borrowValue = _userBorrowValue(_router, _borrowToken(_router), _user);
        if (borrowValue == 0) return; // No borrows = always healthy

        uint256 maxCollateralValue = _userCollateralStats(_router, _collateralToken(_router), _user);
        // If user has borrows but insufficient collateral, revert
        if (borrowValue > maxCollateralValue) revert LiquidationAlert(borrowValue, maxCollateralValue);
    }

    function checkLiquidatable(address user, address lendingPool)
        public
        view
        returns (bool, uint256, uint256, uint256)
    {
        uint256 borrowValue = _userBorrowValue(lendingPool, _borrowToken(lendingPool), user);
        if (borrowValue == 0) return (true, 0, 0, 0);
        uint256 maxCollateralValue = _userCollateralStats(lendingPool, _collateralToken(lendingPool), user);
        uint256 liquidationAllocation = _userCollateral(lendingPool, user) * liquidationBonus[lendingPool] / 1e18;
        return (borrowValue > maxCollateralValue, borrowValue, maxCollateralValue, liquidationAllocation);
    }

    // =============================================================
    //                   CONFIGURATION FUNCTIONS
    // =============================================================

    /// @notice Updates the factory contract address
    /// @dev Only the contract owner can call this function
    /// @param _factory The new factory contract address
    function setFactory(address _factory) public onlyOwner {
        if (_factory == address(0)) revert ZeroAddress();
        factory = _factory;
        emit FactorySet(_factory);
    }

    function setLiquidationThreshold(address _router, uint256 _threshold) public onlyFactory {
        uint256 ltv = _ltv(_router);
        if (ltv > _threshold) revert LtvMustBeLessThanThreshold(_router, ltv, _threshold);
        liquidationThreshold[_router] = _threshold;
        emit LiquidationThresholdSet(_router, _threshold);
    }

    function setLiquidationBonus(address _router, uint256 bonus) public onlyFactory {
        liquidationBonus[_router] = bonus;
        emit LiquidationBonusSet(_router, bonus);
    }

    // =============================================================
    //                    INTERNAL HELPER FUNCTIONS
    // =============================================================

    function _userCollateralStats(address _router, address _token, address _user) internal view returns (uint256) {
        _checkLiquidation(_router);
        uint256 userCollateral = _userCollateral(_router, _user);
        uint256 collateralAdjustedPrice = (_tokenPrice(_token) * 1e18) / (10 ** _oracleDecimal(_token));
        uint256 userCollateralValue = (userCollateral * collateralAdjustedPrice) / (10 ** _tokenDecimals(_token));
        uint256 maxBorrowValue = (userCollateralValue * liquidationThreshold[_router]) / 1e18;
        return maxBorrowValue;
    }

    function _userBorrowValue(address _router, address _token, address _user) internal view returns (uint256) {
        uint256 shares = _userBorrowShares(_router, _user);
        if (shares == 0) return 0;
        if (_totalBorrowShares(_router) == 0) return 0;
        uint256 userBorrowAmount = (shares * _totalBorrowAssets(_router)) / _totalBorrowShares(_router);
        uint256 borrowAdjustedPrice = (_tokenPrice(_token) * 1e18) / (10 ** _oracleDecimal(_token));
        uint256 userBorrowValue = (userBorrowAmount * borrowAdjustedPrice) / (10 ** _tokenDecimals(_token));
        return userBorrowValue;
    }

    function _collateralToken(address _router) internal view returns (address) {
        return ILPRouter(_router).collateralToken();
    }

    function _borrowToken(address _router) internal view returns (address) {
        return ILPRouter(_router).borrowToken();
    }

    function _userBorrowShares(address _router, address _user) internal view returns (uint256) {
        return ILPRouter(_router).userBorrowShares(_user);
    }

    function _totalBorrowAssets(address _router) internal view returns (uint256) {
        return ILPRouter(_router).totalBorrowAssets();
    }

    function _totalBorrowShares(address _router) internal view returns (uint256) {
        return ILPRouter(_router).totalBorrowShares();
    }

    function _userPosition(address _router, address _user) internal view returns (address) {
        return ILPRouter(_router).addressPositions(_user);
    }

    function _userCollateral(address _router, address _user) internal view returns (uint256) {
        return IPosition(_userPosition(_router, _user)).totalCollateral();
        // return IERC20(_collateralToken(_lendingPool)).balanceOf(_userPosition(_lendingPool, _user));
    }

    function _ltv(address _router) internal view returns (uint256) {
        uint256 ltv = ILPRouter(_router).ltv();
        if (ltv == 0) revert InvalidLtv(_router, ltv);
        return ltv;
    }

    /// @notice Gets the current price of a collateral token from the price feed
    /// @dev Retrieves the latest price data from the TokenDataStream oracle
    /// @param _token The token address to get the price for
    /// @return The current price of the token from the oracle
    function _tokenPrice(address _token) internal view returns (uint256) {
        (, uint256 price,,,) = ITokenDataStream(_tokenDataStream()).latestRoundData(_token);
        return price;
    }

    function _tokenDataStream() internal view returns (address) {
        return IFactory(factory).tokenDataStream();
    }

    /// @notice Gets the number of decimals used by the oracle for a token's price
    /// @dev Used to properly normalize price values from different oracle sources
    /// @param _token The token address to get oracle decimals for
    /// @return The number of decimals used by the token's price oracle
    function _oracleDecimal(address _token) internal view returns (uint256) {
        return ITokenDataStream(_tokenDataStream()).decimals(_token);
    }

    /// @notice Gets the number of decimals used by an ERC20 token
    /// @dev Used to properly normalize token amounts for value calculations
    /// @param _token The token address to get decimals for
    /// @return The number of decimals used by the ERC20 token
    function _tokenDecimals(address _token) internal view returns (uint256) {
        if (_token == address(1) || _token == IFactory(factory).WRAPPED_NATIVE()) {
            return 18;
        }
        return IERC20Metadata(_token).decimals();
    }

    function _checkLiquidation(address _lendingPool) internal view {
        if (liquidationThreshold[_lendingPool] == 0) revert LiquidationThresholdNotSet(_lendingPool);
        if (liquidationBonus[_lendingPool] == 0) revert LiquidationBonusNotSet(_lendingPool);
    }

    function _onlyFactory() internal view {
        if (msg.sender != factory) revert NotFactory();
    }
}
