// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFactory} from "./interfaces/IFactory.sol";
import {IPositionDeployer} from "./interfaces/IPositionDeployer.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

/**
 * @title LendingPoolRouter
 * @author Senja Protocol
 * @notice Router contract that manages lending pool operations and state
 * @dev This contract handles the core logic for supply, borrow, repay, liquidation operations,
 *      and interest calculations. It maintains the state of all user positions and implements
 *      a dynamic interest rate model based on pool utilization. The contract works in tandem
 *      with the LendingPool contract which handles token transfers and external interactions.
 */
contract LendingPoolRouter {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when amount is zero
    error ZeroAmount();

    /// @notice Error thrown when user has insufficient shares
    error InsufficientShares();

    /// @notice Error thrown when protocol has insufficient liquidity
    error InsufficientLiquidity();

    /// @notice Error thrown when caller is not the lending pool
    error NotLendingPool();

    /// @notice Error thrown when caller is not the factory
    error NotFactory();

    /// @notice Error thrown when position already exists
    error PositionAlreadyCreated();

    /**
     * @notice Error thrown when total supply shares is zero
     * @param shares The shares being withdrawn
     * @param totalSupplyShares The current total supply shares (should be zero)
     */
    error TotalSupplySharesZero(uint256 shares, uint256 totalSupplyShares);

    /**
     * @notice Error thrown when user has insufficient collateral
     * @param amount The actual collateral amount
     * @param expectedAmount The expected collateral amount
     */
    error InsufficientCollateral(uint256 amount, uint256 expectedAmount);

    /**
     * @notice Error thrown when total borrow shares is zero
     * @param shares The shares being repaid
     * @param totalBorrowShares The current total borrow shares (should be zero)
     */
    error TotalBorrowSharesZero(uint256 shares, uint256 totalBorrowShares);

    /**
     * @notice Error thrown when user is not liquidatable
     * @param user The address of the user
     */
    error NotLiquidable(address user);

    /**
     * @notice Error thrown when asset is not liquidatable
     * @param collateralToken The address of the collateral token
     * @param collateralValue The value of the collateral
     * @param borrowValue The value of the borrow
     */
    error AssetNotLiquidatable(address collateralToken, uint256 collateralValue, uint256 borrowValue);

    /**
     * @notice Error thrown when maximum utilization is reached
     * @param borrowToken The address of the borrow token
     * @param newUtilization The new utilization rate
     * @param maxUtilization The maximum allowed utilization rate
     */
    error MaxUtilizationReached(address borrowToken, uint256 newUtilization, uint256 maxUtilization);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Total supply assets in the pool
    uint256 public totalSupplyAssets;

    /// @notice Total supply shares issued
    uint256 public totalSupplyShares;

    /// @notice Total borrowed assets from the pool
    uint256 public totalBorrowAssets;

    /// @notice Total borrow shares issued
    uint256 public totalBorrowShares;

    /// @notice Mapping of user to their supply shares
    mapping(address => uint256) public userSupplyShares;

    /// @notice Mapping of user to their borrow shares
    mapping(address => uint256) public userBorrowShares;

    /// @notice Mapping of user to their position contract address
    mapping(address => address) public addressPositions;

    /// @notice Timestamp of last interest accrual
    uint256 public lastAccrued;

    /// @notice Address of the lending pool contract
    address public lendingPool;

    /// @notice Address of the factory contract
    address public factory;

    /// @notice Address of the collateral token
    address public collateralToken;

    /// @notice Address of the borrow token
    address public borrowToken;

    /// @notice Loan-to-value ratio in basis points (e.g., 8000 = 80%)
    uint256 public ltv;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the LendingPoolRouter contract
     * @dev Sets up the initial state with lending pool, factory, and market parameters
     * @param _lendingPool The address of the lending pool contract
     * @param _factory The address of the factory contract
     * @param _collateralToken The address of the collateral token
     * @param _borrowToken The address of the borrow token
     * @param _ltv The loan-to-value ratio in basis points (e.g., 8000 = 80%)
     */
    constructor(address _lendingPool, address _factory, address _collateralToken, address _borrowToken, uint256 _ltv) {
        lendingPool = _lendingPool;
        factory = _factory;
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
        ltv = _ltv;
        lastAccrued = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts function access to factory contract only
     * @dev Reverts with NotFactory if caller is not the factory
     */
    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    /**
     * @notice Restricts function access to lending pool contract only
     * @dev Reverts with NotLendingPool if caller is not the lending pool
     */
    modifier onlyLendingPool() {
        _onlyLendingPool();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL GUARD FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to check if caller is the factory
     * @dev Reverts with NotFactory if msg.sender is not the factory address
     */
    function _onlyFactory() internal view {
        if (msg.sender != factory) revert NotFactory();
    }

    /**
     * @notice Internal function to check if caller is the lending pool
     * @dev Reverts with NotLendingPool if msg.sender is not the lending pool address
     */
    function _onlyLendingPool() internal view {
        if (msg.sender != lendingPool) revert NotLendingPool();
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a new lending pool address
     * @dev Only callable by factory contract
     * @param _lendingPool The new lending pool address
     */
    function setLendingPool(address _lendingPool) public onlyFactory {
        lendingPool = _lendingPool;
    }

    /*//////////////////////////////////////////////////////////////
                         SUPPLY/WITHDRAW LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Supplies liquidity to the pool and mints shares to the user
     * @dev Only callable by lending pool. Uses a shares-based accounting system.
     *      First depositor receives shares equal to amount (1:1).
     *      Subsequent depositors receive shares proportional to their contribution.
     * @param _amount The amount of assets to supply
     * @param _user The address of the user supplying liquidity
     * @return shares The number of shares minted to the user
     */
    function supplyLiquidity(uint256 _amount, address _user) public onlyLendingPool returns (uint256 shares) {
        if (_amount == 0) revert ZeroAmount();
        shares = 0;
        if (totalSupplyAssets == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupplyShares) / totalSupplyAssets;
        }

        userSupplyShares[_user] += shares;
        totalSupplyShares += shares;
        totalSupplyAssets += _amount;

        return shares;
    }

    /**
     * @notice Withdraws liquidity from the pool by burning shares
     * @dev Only callable by lending pool. Converts shares back to assets proportionally.
     *      Ensures sufficient liquidity remains after withdrawal.
     * @param _shares The number of shares to burn
     * @param _user The address of the user withdrawing liquidity
     * @return amount The amount of assets withdrawn
     */
    function withdrawLiquidity(uint256 _shares, address _user) public onlyLendingPool returns (uint256 amount) {
        if (_shares == 0) revert ZeroAmount();
        if (_shares > userSupplyShares[_user]) revert InsufficientShares();
        if (totalSupplyShares == 0) revert TotalSupplySharesZero(_shares, totalSupplyShares);

        amount = ((_shares * totalSupplyAssets) / totalSupplyShares);

        userSupplyShares[_user] -= _shares;
        totalSupplyShares -= _shares;
        totalSupplyAssets -= amount;

        if (totalSupplyAssets < totalBorrowAssets) {
            revert InsufficientLiquidity();
        }

        return amount;
    }

    /*//////////////////////////////////////////////////////////////
                      INTEREST RATE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate dynamic borrow rate based on utilization rate
     * @dev Implements a two-slope interest rate model:
     *      - Below optimal utilization (80%): Linear increase from 2% to 10%
     *      - Above optimal utilization: Sharp increase from 10% to 50%
     *      This encourages borrowing up to optimal point and discourages over-borrowing
     * @return borrowRate The annual borrow rate in percentage (scaled by 100, e.g., 1000 = 10%)
     */
    function calculateBorrowRate() public view returns (uint256 borrowRate) {
        if (totalSupplyAssets == 0) {
            return 500; // 5% base rate when no supply (scaled by 100)
        }

        // Calculate utilization rate (scaled by 10000 for precision)
        uint256 utilizationRate = (totalBorrowAssets * 10000) / totalSupplyAssets;

        // Interest rate model parameters
        uint256 baseRate = 200; // 2% base rate (scaled by 100)
        uint256 optimalUtilization = 8000; // 80% optimal utilization (scaled by 10000)
        uint256 rateAtOptimal = 1000; // 10% rate at optimal utilization (scaled by 100)
        uint256 maxRate = 5000; // 50% maximum rate (scaled by 100)

        if (utilizationRate <= optimalUtilization) {
            // Linear increase from base rate to optimal rate
            // Rate = baseRate + (utilizationRate * (rateAtOptimal - baseRate)) / optimalUtilization
            borrowRate = baseRate + ((utilizationRate * (rateAtOptimal - baseRate)) / optimalUtilization);
        } else {
            // Sharp increase after optimal utilization to discourage over-borrowing
            uint256 excessUtilization = utilizationRate - optimalUtilization;
            uint256 maxExcessUtilization = 10000 - optimalUtilization; // 20% (scaled by 10000)

            // Rate = rateAtOptimal + (excessUtilization * (maxRate - rateAtOptimal)) / maxExcessUtilization
            borrowRate = rateAtOptimal + ((excessUtilization * (maxRate - rateAtOptimal)) / maxExcessUtilization);
        }

        return borrowRate;
    }

    /**
     * @notice Get current utilization rate of the pool
     * @dev Utilization rate = (totalBorrowAssets / totalSupplyAssets) * 10000
     * @return utilizationRate The utilization rate scaled by 10000 (e.g., 8000 = 80%)
     */
    function getUtilizationRate() public view returns (uint256 utilizationRate) {
        if (totalSupplyAssets == 0) {
            return 0;
        }

        // Return utilization rate scaled by 10000 (e.g., 8000 = 80.00%)
        utilizationRate = (totalBorrowAssets * 10000) / totalSupplyAssets;
        return utilizationRate;
    }

    /**
     * @notice Calculate supply rate based on borrow rate and utilization
     * @dev Supply rate = Borrow rate × Utilization rate × (1 - reserve factor)
     *      Reserve factor is set at 10%, meaning 90% of interest goes to suppliers
     * @return supplyRate The annual supply rate in percentage (scaled by 100, e.g., 500 = 5%)
     */
    function calculateSupplyRate() public view returns (uint256 supplyRate) {
        if (totalSupplyAssets == 0) {
            return 0;
        }

        uint256 borrowRate = calculateBorrowRate();
        uint256 utilizationRate = (totalBorrowAssets * 10000) / totalSupplyAssets;
        uint256 reserveFactor = 1000; // 10% reserve factor (scaled by 10000)

        // supplyRate = borrowRate * utilizationRate * (1 - reserveFactor) / 10000
        supplyRate = (borrowRate * utilizationRate * (10000 - reserveFactor)) / (10000 * 10000);

        return supplyRate;
    }

    /**
     * @notice Accrues interest to the pool
     * @dev Calculates interest based on elapsed time since last accrual and adds it
     *      to both totalSupplyAssets and totalBorrowAssets. This increases the value
     *      of supply shares and borrow shares proportionally.
     */
    function accrueInterest() public {
        uint256 elapsedTime = block.timestamp - lastAccrued;
        if (elapsedTime == 0) return; // No time elapsed, skip
        lastAccrued = block.timestamp;
        if (totalBorrowAssets == 0) return;
        uint256 interest = IInterestRateModel(_interestRateModel()).calculateInterest(address(this), elapsedTime);
        totalSupplyAssets += interest;
        totalBorrowAssets += interest;
    }

    /*//////////////////////////////////////////////////////////////
                          BORROW/REPAY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Borrows assets from the pool
     * @dev Only callable by lending pool. Mints borrow shares to the user and applies
     *      a 0.1% protocol fee. Checks maximum utilization to prevent over-borrowing.
     * @param _amount The amount of assets to borrow
     * @param _user The address of the user borrowing
     * @return protocolFee The protocol fee taken (0.1% of borrow amount)
     * @return userAmount The amount user receives after fee
     * @return shares The number of borrow shares minted
     */
    function borrowDebt(uint256 _amount, address _user)
        public
        onlyLendingPool
        returns (uint256 protocolFee, uint256 userAmount, uint256 shares)
    {
        if (_amount == 0) revert ZeroAmount();

        shares = 0;
        if (totalBorrowShares == 0) {
            shares = _amount;
        } else {
            shares = ((_amount * totalBorrowShares) / totalBorrowAssets);
        }
        userBorrowShares[_user] += shares;
        totalBorrowShares += shares;
        totalBorrowAssets += _amount;

        uint256 newUtilization = (totalBorrowAssets * 1e18) / totalSupplyAssets;

        if (newUtilization >= _maxUtilization()) {
            revert MaxUtilizationReached(borrowToken, newUtilization, _maxUtilization());
        }

        protocolFee = (_amount * 1e15) / 1e18; // 0.1%
        userAmount = _amount - protocolFee;

        if (totalBorrowAssets > totalSupplyAssets) {
            revert InsufficientLiquidity();
        }

        return (protocolFee, userAmount, shares);
    }

    /**
     * @notice Repays borrowed assets by burning borrow shares
     * @dev Only callable by lending pool. Converts borrow shares to assets and burns them.
     * @param _shares The number of borrow shares to burn
     * @param _user The address of the user repaying
     * @return borrowAmount The amount of assets repaid
     * @return userBorrowSharesAfter The user's remaining borrow shares
     * @return totalBorrowSharesAfter The total borrow shares after repayment
     * @return totalBorrowAssetsAfter The total borrow assets after repayment
     */
    function repayWithSelectedToken(uint256 _shares, address _user)
        public
        onlyLendingPool
        returns (uint256, uint256, uint256, uint256)
    {
        if (_shares == 0) revert ZeroAmount();
        if (_shares > userBorrowShares[_user]) revert InsufficientShares();
        if (totalBorrowShares == 0) revert TotalBorrowSharesZero(_shares, totalBorrowShares);

        uint256 borrowAmount = ((_shares * totalBorrowAssets) / totalBorrowShares);
        userBorrowShares[_user] -= _shares;
        totalBorrowShares -= _shares;
        totalBorrowAssets -= borrowAmount;

        return (borrowAmount, userBorrowShares[_user], totalBorrowShares, totalBorrowAssets);
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Liquidates an undercollateralized position
     * @dev Only callable by lending pool. Checks if position is liquidatable via health check,
     *      accrues interest before liquidation, and clears borrower's position.
     *      Liquidator receives most of the collateral while a portion goes to protocol.
     * @param _borrower The address of the borrower being liquidated
     * @return userBorrowAssets The total borrow assets of the borrower
     * @return borrowerCollateral The total collateral of the borrower
     * @return liquidationAllocation The amount allocated to protocol
     * @return collateralToLiquidator The amount of collateral going to liquidator
     * @return userPosition The address of the borrower's position contract
     */
    function liquidation(address _borrower)
        public
        onlyLendingPool
        returns (
            uint256 userBorrowAssets,
            uint256 borrowerCollateral,
            uint256 liquidationAllocation,
            uint256 collateralToLiquidator,
            address userPosition
        )
    {
        // Check if borrower is authorized (has position)
        if (userBorrowShares[_borrower] == 0 && _userCollateral(_borrower) == 0) {
            revert NotLiquidable(_borrower);
        }

        // Check if position is liquidatable
        (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue, uint256 liquidationAllocationCalc) =
            IIsHealthy(_isHealthy()).checkLiquidatable(_borrower, address(this));

        if (!isLiquidatable) {
            revert AssetNotLiquidatable(collateralToken, collateralValue, borrowValue);
        }

        // Accrue interest before liquidation
        accrueInterest();

        // Get borrower's state
        borrowerCollateral = _userCollateral(_borrower);
        userBorrowAssets = _borrowSharesToAmount(userBorrowShares[_borrower]);
        liquidationAllocation = liquidationAllocationCalc;
        userPosition = addressPositions[_borrower];

        // Ensure liquidation allocation doesn't exceed borrower collateral
        if (liquidationAllocation > borrowerCollateral) {
            liquidationAllocation = 0;
        }

        collateralToLiquidator = borrowerCollateral - liquidationAllocation;

        // Update state: clear borrower's position
        totalBorrowAssets -= userBorrowAssets;
        totalBorrowShares -= userBorrowShares[_borrower];
        userBorrowShares[_borrower] = 0;
        addressPositions[_borrower] = address(0);

        return (userBorrowAssets, borrowerCollateral, liquidationAllocation, collateralToLiquidator, userPosition);
    }

    /*//////////////////////////////////////////////////////////////
                         POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new position contract for a user
     * @dev Only callable by lending pool. Deploys a new Position contract via factory
     *      and stores it in addressPositions mapping. Reverts if position already exists.
     * @param _user The address of the user
     * @return The address of the newly created position contract
     */
    function createPosition(address _user) public onlyLendingPool returns (address) {
        if (addressPositions[_user] != address(0)) revert PositionAlreadyCreated();
        address position = IPositionDeployer(_positionDeployer()).deployPosition(lendingPool, _user);
        addressPositions[_user] = position;
        return position;
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the total collateral of a user from their position
     * @dev Internal view function that queries the user's position contract
     * @param _user The address of the user
     * @return The total collateral amount held in user's position
     */
    function _userCollateral(address _user) internal view returns (uint256) {
        return IPosition(addressPositions[_user]).totalCollateral();
    }

    /**
     * @notice Gets the health checker contract address from factory
     * @dev Internal view function that queries the factory for the IsHealthy contract
     * @return The address of the IsHealthy contract
     */
    function _isHealthy() internal view returns (address) {
        return IFactory(factory).isHealthy();
    }

    /**
     * @notice Converts borrow shares to borrow assets
     * @dev Internal view function for shares-to-assets conversion
     * @param _shares The number of borrow shares
     * @return The equivalent amount of borrow assets
     */
    function _borrowSharesToAmount(uint256 _shares) internal view returns (uint256) {
        return (_shares * totalBorrowAssets) / totalBorrowShares;
    }

    /**
     * @notice Gets the interest rate model contract address from factory
     * @dev Internal view function that queries the factory
     * @return The address of the interest rate model contract
     */
    function _interestRateModel() internal view returns (address) {
        return IFactory(factory).interestRateModel();
    }

    /**
     * @notice Gets the maximum utilization allowed for this lending pool
     * @dev Internal view function that queries the interest rate model
     * @return The maximum utilization rate (scaled by 1e18)
     */
    function _maxUtilization() internal view returns (uint256) {
        return IInterestRateModel(_interestRateModel()).lendingPoolMaxUtilization(address(this));
    }

    /**
     * @notice Gets the position deployer address from factory
     * @dev Internal view function that queries the factory for the PositionDeployer contract
     * @return The address of the position deployer contract
     */
    function _positionDeployer() internal view returns (address) {
        return IFactory(factory).positionDeployer();
    }
}
