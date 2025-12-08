// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";

/**
 * @title InterestRateModel
 * @author Senja Labs
 * @notice Manages interest rate calculations for lending pool tokens using a two-slope model
 * @dev This contract implements a dynamic interest rate model based on utilization rates.
 *      The model uses two slopes: one from 0% to optimal utilization, and another from optimal to max utilization.
 */
contract InterestRateModel is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    // =============================================================
    //                           ERRORS
    // =============================================================

    /// @notice Thrown when the utilization rate exceeds the maximum utilization rate
    /// @param _token The token address that has exceeded the maximum utilization rate
    /// @param _utilization The utilization rate that exceeded the maximum utilization rate
    /// @param _maxUtilization The maximum utilization rate
    error MaxUtilizationReached(address _token, uint256 _utilization, uint256 _maxUtilization);

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @notice Role identifier for accounts that have owner privileges
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @notice Role identifier for accounts that can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================
    //                       STATE VARIABLES
    // =============================================================

    /// @notice Base interest rate for each token (scaled by 1e18, e.g., 5e16 = 5%)
    /// @dev Lending Pool Router address => base rate
    mapping(address => uint256) public lendingPoolBaseRate;

    /// @notice Interest rate at optimal utilization for each token (scaled by 1e18, e.g., 10e16 = 10%)
    /// @dev Lending Pool Router address => rate at optimal
    mapping(address => uint256) public lendingPoolRateAtOptimal;

    /// @notice Optimal utilization rate for each token (scaled by 1e18, e.g., 75e16 = 75%)
    /// @dev Lending Pool Router address => optimal utilization
    mapping(address => uint256) public lendingPoolOptimalUtilization;

    /// @notice Maximum allowed utilization rate for each token (scaled by 1e18, e.g., 95e16 = 95%)
    /// @dev Lending Pool Router address => max utilization
    mapping(address => uint256) public lendingPoolMaxUtilization;

    /// @notice Reserve factor for each token (scaled by 1e18, e.g., 1e18 = 100%)
    /// @dev Lending Pool Router address => reserve factor
    mapping(address => uint256) public tokenReserveFactor;

    /// @notice Scaled percentage base for calculations (basis points, e.g., 1e18 = 100%)
    uint256 public scaledPercentage;

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @notice Emitted when a lending pool's base rate is updated
    /// @param lendingPool The lending pool address
    /// @param rate The new base rate
    event LendingPoolBaseRateSet(address indexed lendingPool, uint256 rate);

    /// @notice Emitted when a lending pool's optimal utilization is updated
    /// @param lendingPool The lending pool address
    /// @param utilization The new optimal utilization
    event LendingPoolOptimalUtilizationSet(address indexed lendingPool, uint256 utilization);

    /// @notice Emitted when a lending pool's max utilization is updated
    /// @param lendingPool The lending pool address
    /// @param utilization The new max utilization
    event LendingPoolMaxUtilizationSet(address indexed lendingPool, uint256 utilization);

    /// @notice Emitted when a lending pool's rate at optimal is updated
    /// @param lendingPool The lending pool address
    /// @param rate The new rate at optimal
    event LendingPoolRateAtOptimalSet(address indexed lendingPool, uint256 rate);

    /// @notice Emitted when the scaled percentage is updated
    /// @param percentage The new scaled percentage
    event ScaledPercentageSet(uint256 percentage);

    /// @notice Emitted when a token's reserve factor is updated
    /// @param lendingPool The lending pool address
    /// @param reserveFactor The new reserve factor
    event TokenReserveFactorSet(address indexed lendingPool, uint256 reserveFactor);

    // =============================================================
    //                           CONSTRUCTOR
    // =============================================================

    /// @notice Contract constructor that disables initializers for the implementation contract
    /// @dev This prevents the implementation contract from being initialized directly
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the upgradeable contract with default settings and roles
    /// @dev This function replaces the constructor for upgradeable contracts.
    ///      Sets up default scaled percentage to 1e18 (100% in basis points)
    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        scaledPercentage = 1e18; // 100% in basis points
    }

    // =============================================================
    //                    INTEREST RATE CALCULATION
    // =============================================================

    /// @notice Calculates the current borrow rate based on utilization
    /// @dev Uses a two-slope interest rate model:
    ///      - Base rate to optimal utilization: linear increase from base rate to rate at optimal
    ///      - Above optimal utilization: sharp increase from rate at optimal to 100%
    ///      - Returns base rate when no supply exists or no borrows exist
    /// @param _lendingPool The token address to calculate borrow rate for
    /// @return borrowRate The annual borrow rate scaled by 100 (e.g., 500 = 5%)
    function calculateBorrowRate(address _lendingPool) public view returns (uint256 borrowRate) {
        if (_totalSupplyAssets(_lendingPool) == 0 || _totalBorrowAssets(_lendingPool) == 0) {
            return lendingPoolBaseRate[_lendingPool]; // Base rate when no supply or no borrows
        }

        // Calculate utilization rate (scaled by 1e18 for precision)
        uint256 utilizationRate =
            (_totalBorrowAssets(_lendingPool) * scaledPercentage) / _totalSupplyAssets(_lendingPool);

        // Interest rate model parameters
        uint256 baseRate = lendingPoolBaseRate[_lendingPool];
        uint256 optimalUtilization = lendingPoolOptimalUtilization[_lendingPool];
        uint256 rateAtOptimal = lendingPoolRateAtOptimal[_lendingPool];

        // Check if utilization exceeds maximum allowed
        if (utilizationRate >= lendingPoolMaxUtilization[_lendingPool]) {
            revert MaxUtilizationReached(
                _borrowToken(_lendingPool), utilizationRate, lendingPoolMaxUtilization[_lendingPool]
            );
        }

        if (utilizationRate <= optimalUtilization) {
            // Linear increase from base rate to optimal rate
            borrowRate = baseRate + ((utilizationRate * (rateAtOptimal - baseRate)) / optimalUtilization);
        } else {
            // Sharp increase after optimal utilization to discourage over-borrowing
            uint256 excessUtilization = utilizationRate - optimalUtilization;
            uint256 maxExcessUtilization = scaledPercentage - optimalUtilization;
            borrowRate =
                rateAtOptimal + ((excessUtilization * (scaledPercentage - rateAtOptimal)) / maxExcessUtilization);
        }

        return borrowRate;
    }

    /// @notice Calculates interest accrued over a time period
    /// @dev Interest = (totalBorrowAssets * borrowRate * elapsedTime) / (10000 * 365 days)
    /// @param _lendingPool The lending pool address
    /// @param _elapsedTime Time elapsed since last accrual in seconds
    /// @return interest The interest amount accrued
    /// @return supplyYield The yield for suppliers
    /// @return reserveYield The yield for reserve
    function calculateInterest(address _lendingPool, uint256 _elapsedTime)
        public
        view
        returns (uint256 interest, uint256 supplyYield, uint256 reserveYield)
    {
        uint256 borrowRate = calculateBorrowRate(_lendingPool);
        uint256 interestPerYear = (_totalBorrowAssets(_lendingPool) * borrowRate) / scaledPercentage; // borrowRate is scaled by 100
        interest = (interestPerYear * _elapsedTime) / 365 days; // 365 days in seconds
        supplyYield = borrowRate * ((scaledPercentage - _tokenReserveFactor(_lendingPool)) / scaledPercentage);
        reserveYield = borrowRate * (_tokenReserveFactor(_borrowToken(_lendingPool)) / scaledPercentage);
        return (interest, supplyYield, reserveYield);
    }

    // =============================================================
    //                    ADMINISTRATIVE FUNCTIONS
    // =============================================================
    /// @notice Sets the base rate for a token
    /// @dev Only OWNER_ROLE can call this. Base rate is the minimum interest rate (scaled by 100)
    /// @param _lendingPool The lending pool address
    /// @param _rate The new base rate (e.g., 500 = 5%)
    function setLendingPoolBaseRate(address _lendingPool, uint256 _rate) public onlyRole(OWNER_ROLE) {
        lendingPoolBaseRate[_lendingPool] = _rate;
        emit LendingPoolBaseRateSet(_lendingPool, _rate);
    }

    /// @notice Sets the optimal utilization rate for a token
    /// @dev Only OWNER_ROLE can call this. Optimal utilization is where the rate curve changes slope (scaled by 1e18)
    /// @param _lendingPool The lending pool address
    /// @param _utilization The new optimal utilization (e.g., 75e16 = 75%)
    function setLendingPoolOptimalUtilization(address _lendingPool, uint256 _utilization) public onlyRole(OWNER_ROLE) {
        lendingPoolOptimalUtilization[_lendingPool] = _utilization;
        emit LendingPoolOptimalUtilizationSet(_lendingPool, _utilization);
    }

    /// @notice Sets the maximum utilization rate for a token
    /// @dev Only OWNER_ROLE can call this. Borrowing is blocked when utilization reaches this threshold (scaled by 1e18)
    /// @param _lendingPool The lending pool address
    /// @param _utilization The new max utilization (e.g., 95e16 = 95%)
    function setLendingPoolMaxUtilization(address _lendingPool, uint256 _utilization) public onlyRole(OWNER_ROLE) {
        lendingPoolMaxUtilization[_lendingPool] = _utilization;
        emit LendingPoolMaxUtilizationSet(_lendingPool, _utilization);
    }

    /// @notice Sets the interest rate at optimal utilization for a token
    /// @dev Only OWNER_ROLE can call this. This is the rate at the optimal utilization point (scaled by 1e18)
    /// @param _lendingPool The lending pool address
    /// @param _rate The new rate at optimal (e.g., 10e16 = 10%)
    function setLendingPoolRateAtOptimal(address _lendingPool, uint256 _rate) public onlyRole(OWNER_ROLE) {
        lendingPoolRateAtOptimal[_lendingPool] = _rate;
        emit LendingPoolRateAtOptimalSet(_lendingPool, _rate);
    }

    /// @notice Sets the scaled percentage base for calculations
    /// @dev Only OWNER_ROLE can call this. Typically set to 1e18 (100% in basis points)
    /// @param _percentage The new scaled percentage
    function setScaledPercentage(uint256 _percentage) public onlyRole(OWNER_ROLE) {
        scaledPercentage = _percentage;
        emit ScaledPercentageSet(_percentage);
    }

    /// @notice Sets the reserve factor for a token
    /// @dev Only OWNER_ROLE can call this. Reserve factor is the percentage of borrow assets that are set aside as reserves (scaled by 1e18)
    /// @param _lendingPool The lending pool address
    /// @param _reserveFactor The new reserve factor (e.g., 10e16 = 10%)
    function setTokenReserveFactor(address _lendingPool, uint256 _reserveFactor) public onlyRole(OWNER_ROLE) {
        tokenReserveFactor[_lendingPool] = _reserveFactor;
        emit TokenReserveFactorSet(_lendingPool, _reserveFactor);
    }

    // =============================================================
    //                   INTERNAL HELPER FUNCTIONS
    // =============================================================
    /**
     * @notice Internal function to get total supply assets from lending pool router
     * @param _router Address of the lending pool router
     * @return Total supply assets in the pool
     */
    function _totalSupplyAssets(address _router) internal view returns (uint256) {
        return ILPRouter(_router).totalSupplyAssets();
    }

    /**
     * @notice Internal function to get total borrow assets from lending pool router
     * @param _router Address of the lending pool router
     * @return Total borrow assets in the pool
     */
    function _totalBorrowAssets(address _router) internal view returns (uint256) {
        return ILPRouter(_router).totalBorrowAssets();
    }

    /**
     * @notice Internal function to get the borrow token address from lending pool router
     * @param _router Address of the lending pool router
     * @return Address of the borrow token
     */
    function _borrowToken(address _router) internal view returns (address) {
        return ILPRouter(_router).borrowToken();
    }

    /**
     * @notice Internal function to get the collateral token address from lending pool router
     * @param _router Address of the lending pool router
     * @return Address of the collateral token
     */
    function _collateralToken(address _router) internal view returns (address) {
        return ILPRouter(_router).collateralToken();
    }

    function _tokenReserveFactor(address _router) internal view returns (uint256) {
        if (tokenReserveFactor[_router] == 0) return 10e16;
        return tokenReserveFactor[_router];
    }

    // =============================================================
    //                       UPGRADE FUNCTIONS
    // =============================================================

    /// @notice Authorizes contract upgrades
    /// @dev Only accounts with UPGRADER_ROLE can authorize upgrades.
    ///      This is required by the UUPSUpgradeable pattern.
    /// @param newImplementation The address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}

