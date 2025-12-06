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
    /// @param lendingPool The lending pool address
    /// @param ltv The invalid LTV ratio that was provided
    error InvalidLtv(address lendingPool, uint256 ltv);

    /// @notice Thrown when user has zero collateral amount
    /// @param lendingPool The lending pool address
    /// @param userCollateralAmount User's collateral amount
    /// @param totalCollateral Total collateral in the system
    error ZeroCollateralAmount(address lendingPool, uint256 userCollateralAmount, uint256 totalCollateral);

    /// @notice Thrown when LTV exceeds the liquidation threshold
    /// @param lendingPool The lending pool address
    /// @param ltv The loan-to-value ratio
    /// @param threshold The liquidation threshold
    error LtvMustBeLessThanThreshold(address lendingPool, uint256 ltv, uint256 threshold);

    /// @notice Thrown when a position is at risk of liquidation
    /// @param borrowValue Total value of borrowed assets
    /// @param collateralValue Total value of collateral
    error LiquidationAlert(uint256 borrowValue, uint256 collateralValue);

    /// @notice Thrown when liquidation threshold is not set for a lending pool
    /// @param lendingPool The lending pool address
    error LiquidationThresholdNotSet(address lendingPool);

    /// @notice Thrown when liquidation bonus is not set for a lending pool
    /// @param lendingPool The lending pool address
    error LiquidationBonusNotSet(address lendingPool);

    /// @notice Thrown when zero address is provided
    error ZeroAddress();

    /// @notice Thrown when caller is not the factory contract
    error NotFactory();

    /// @notice Emitted when the factory address is updated
    /// @param factory The new factory address
    event FactorySet(address factory);

    /// @notice Emitted when liquidation threshold is set for a lending pool
    /// @param lendingPool The lending pool address
    /// @param threshold The liquidation threshold value
    event LiquidationThresholdSet(address lendingPool, uint256 threshold);

    /// @notice Emitted when liquidation bonus is set for a lending pool
    /// @param lendingPool The lending pool address
    /// @param bonus The liquidation bonus value
    event LiquidationBonusSet(address lendingPool, uint256 bonus);

    /// @notice Emitted when maximum liquidation percentage is updated
    /// @param percentage The new maximum liquidation percentage
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

    /// @notice Modifier to restrict access to factory contract only
    /// @dev Reverts with NotFactory error if caller is not the factory
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

    /**
     * @notice Checks if a user's position is liquidatable and returns liquidation details
     * @param user The user address to check
     * @param lendingPool The lending pool address
     * @return isLiquidatable Boolean indicating if position can be liquidated
     * @return borrowValue Total value of user's borrowed assets
     * @return maxCollateralValue Maximum collateral value considering liquidation threshold
     * @return liquidationAllocation Bonus allocation for liquidator
     * @dev Returns (true, 0, 0, 0) if user has no borrows
     */
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

    /**
     * @notice Sets the liquidation threshold for a lending pool
     * @param _router The lending pool router address
     * @param _threshold The liquidation threshold value (e.g., 0.85e18 = 85%)
     * @dev Only callable by factory contract. LTV must be less than threshold.
     */
    function setLiquidationThreshold(address _router, uint256 _threshold) public onlyFactory {
        uint256 ltv = _ltv(_router);
        if (ltv > _threshold) revert LtvMustBeLessThanThreshold(_router, ltv, _threshold);
        liquidationThreshold[_router] = _threshold;
        emit LiquidationThresholdSet(_router, _threshold);
    }

    /**
     * @notice Sets the liquidation bonus for a lending pool
     * @param _router The lending pool router address
     * @param bonus The liquidation bonus value (e.g., 0.05e18 = 5% bonus)
     * @dev Only callable by factory contract
     */
    function setLiquidationBonus(address _router, uint256 bonus) public onlyFactory {
        liquidationBonus[_router] = bonus;
        emit LiquidationBonusSet(_router, bonus);
    }

    // =============================================================
    //                    INTERNAL HELPER FUNCTIONS
    // =============================================================

    /**
     * @notice Calculates user's maximum borrowing capacity based on collateral
     * @param _router The lending pool router address
     * @param _token The collateral token address
     * @param _user The user address
     * @return Maximum borrow value considering liquidation threshold
     * @dev Checks liquidation settings, calculates collateral value, and applies liquidation threshold
     */
    function _userCollateralStats(address _router, address _token, address _user) internal view returns (uint256) {
        _checkLiquidation(_router);
        uint256 userCollateral = _userCollateral(_router, _user);
        uint256 collateralAdjustedPrice = (_tokenPrice(_token) * 1e18) / (10 ** _oracleDecimal(_token));
        uint256 userCollateralValue = (userCollateral * collateralAdjustedPrice) / (10 ** _tokenDecimals(_token));
        uint256 maxBorrowValue = (userCollateralValue * liquidationThreshold[_router]) / 1e18;
        return maxBorrowValue;
    }

    /**
     * @notice Calculates the USD value of user's borrowed assets
     * @param _router The lending pool router address
     * @param _token The borrow token address
     * @param _user The user address
     * @return Total borrow value in USD
     * @dev Converts user's borrow shares to assets and calculates USD value using oracle price
     */
    function _userBorrowValue(address _router, address _token, address _user) internal view returns (uint256) {
        uint256 shares = _userBorrowShares(_router, _user);
        if (shares == 0) return 0;
        if (_totalBorrowShares(_router) == 0) return 0;
        uint256 userBorrowAmount = (shares * _totalBorrowAssets(_router)) / _totalBorrowShares(_router);
        uint256 borrowAdjustedPrice = (_tokenPrice(_token) * 1e18) / (10 ** _oracleDecimal(_token));
        uint256 userBorrowValue = (userBorrowAmount * borrowAdjustedPrice) / (10 ** _tokenDecimals(_token));
        return userBorrowValue;
    }

    /**
     * @notice Gets the collateral token address from router
     * @param _router The lending pool router address
     * @return Address of the collateral token
     */
    function _collateralToken(address _router) internal view returns (address) {
        return ILPRouter(_router).collateralToken();
    }

    /**
     * @notice Gets the borrow token address from router
     * @param _router The lending pool router address
     * @return Address of the borrow token
     */
    function _borrowToken(address _router) internal view returns (address) {
        return ILPRouter(_router).borrowToken();
    }

    /**
     * @notice Gets user's borrow shares from router
     * @param _router The lending pool router address
     * @param _user The user address
     * @return User's borrow shares
     */
    function _userBorrowShares(address _router, address _user) internal view returns (uint256) {
        return ILPRouter(_router).userBorrowShares(_user);
    }

    /**
     * @notice Gets total borrow assets from router
     * @param _router The lending pool router address
     * @return Total borrow assets in the pool
     */
    function _totalBorrowAssets(address _router) internal view returns (uint256) {
        return ILPRouter(_router).totalBorrowAssets();
    }

    /**
     * @notice Gets total borrow shares from router
     * @param _router The lending pool router address
     * @return Total borrow shares in the pool
     */
    function _totalBorrowShares(address _router) internal view returns (uint256) {
        return ILPRouter(_router).totalBorrowShares();
    }

    /**
     * @notice Gets user's position contract address from router
     * @param _router The lending pool router address
     * @param _user The user address
     * @return Address of user's position contract
     */
    function _userPosition(address _router, address _user) internal view returns (address) {
        return ILPRouter(_router).addressPositions(_user);
    }

    /**
     * @notice Gets user's total collateral amount from their position
     * @param _router The lending pool router address
     * @param _user The user address
     * @return Total collateral amount held in user's position
     */
    function _userCollateral(address _router, address _user) internal view returns (uint256) {
        return IPosition(_userPosition(_router, _user)).totalCollateral();
        // return IERC20(_collateralToken(_lendingPool)).balanceOf(_userPosition(_lendingPool, _user));
    }

    /**
     * @notice Gets the loan-to-value ratio from router
     * @param _router The lending pool router address
     * @return LTV ratio for the lending pool
     * @dev Reverts if LTV is zero
     */
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

    /**
     * @notice Gets the token data stream contract address from factory
     * @return Address of the token data stream contract
     */
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

    /**
     * @notice Validates that liquidation settings are configured for a lending pool
     * @param _lendingPool The lending pool address to check
     * @dev Reverts if liquidation threshold or bonus is not set
     */
    function _checkLiquidation(address _lendingPool) internal view {
        if (liquidationThreshold[_lendingPool] == 0) revert LiquidationThresholdNotSet(_lendingPool);
        if (liquidationBonus[_lendingPool] == 0) revert LiquidationBonusNotSet(_lendingPool);
    }

    /**
     * @notice Internal function to check if caller is the factory contract
     * @dev Reverts with NotFactory error if caller is not the factory
     */
    function _onlyFactory() internal view {
        if (msg.sender != factory) revert NotFactory();
    }
}
