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
 * @dev This contract handles the core logic for supply, borrow, and interest calculations
 */
contract LendingPoolRouter {
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
    /// @notice Error thrown when total supply shares is zero
    error TotalSupplySharesZero(uint256 shares, uint256 totalSupplyShares);
    /// @notice Error thrown when user has insufficient collateral
    error InsufficientCollateral(uint256 amount, uint256 expectedAmount);
    error TotalBorrowSharesZero(uint256 shares, uint256 totalBorrowShares);
    error NotLiquidable(address user);
    error AssetNotLiquidatable(address collateralToken, uint256 collateralValue, uint256 borrowValue);
    error MaxUtilizationReached(address borrowToken, uint256 newUtilization, uint256 maxUtilization);

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
    /// @notice Loan-to-value ratio in basis points
    uint256 public ltv;

    constructor(address _lendingPool, address _factory, address _collateralToken, address _borrowToken, uint256 _ltv) {
        lendingPool = _lendingPool;
        factory = _factory;
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
        ltv = _ltv;
        lastAccrued = block.timestamp;
    }

    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    modifier onlyLendingPool() {
        _onlyLendingPool();
        _;
    }

    function _onlyFactory() internal view {
        if (msg.sender != factory) revert NotFactory();
    }

    function _onlyLendingPool() internal view {
        if (msg.sender != lendingPool) revert NotLendingPool();
    }

    function setLendingPool(address _lendingPool) public onlyFactory {
        lendingPool = _lendingPool;
    }

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

    /**
     * @dev Calculate dynamic borrow rate based on utilization rate
     * @return borrowRate The annual borrow rate in percentage (scaled by 100)
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
     * @dev Get current utilization rate
     * @return utilizationRate The utilization rate in percentage (scaled by 100)
     */
    function getUtilizationRate() public view returns (uint256 utilizationRate) {
        if (totalSupplyAssets == 0) {
            return 0;
        }

        // Return utilization rate scaled by 100 (e.g., 8000 = 80.00%)
        utilizationRate = (totalBorrowAssets * 10000) / totalSupplyAssets;
        return utilizationRate;
    }

    /**
     * @dev Calculate supply rate based on borrow rate and utilization
     * Supply rate = Borrow rate * Utilization rate * (1 - reserve factor)
     * @return supplyRate The annual supply rate in percentage (scaled by 100)
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

    function accrueInterest() public {
        uint256 elapsedTime = block.timestamp - lastAccrued;
        if (elapsedTime == 0) return; // No time elapsed, skip
        lastAccrued = block.timestamp;
        if (totalBorrowAssets == 0) return;
        uint256 interest = IInterestRateModel(_interestRateModel()).calculateInterest(address(this), elapsedTime);
        totalSupplyAssets += interest;
        totalBorrowAssets += interest;
    }

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

    function createPosition(address _user) public onlyLendingPool returns (address) {
        if (addressPositions[_user] != address(0)) revert PositionAlreadyCreated();
        address position = IPositionDeployer(_positionDeployer()).deployPosition(lendingPool, _user);
        addressPositions[_user] = position;
        return position;
    }

    function _userCollateral(address _user) internal view returns (uint256) {
        return IPosition(addressPositions[_user]).totalCollateral();
    }

    function _isHealthy() internal view returns (address) {
        return IFactory(factory).isHealthy();
    }

    function _borrowSharesToAmount(uint256 _shares) internal view returns (uint256) {
        return (_shares * totalBorrowAssets) / totalBorrowShares;
    }

    function _interestRateModel() internal view returns (address) {
        return IFactory(factory).interestRateModel();
    }

    function _maxUtilization() internal view returns (uint256) {
        return IInterestRateModel(_interestRateModel()).lendingPoolMaxUtilization(address(this));
    }

    /**
     * @notice Gets the position deployer address from factory
     * @return The address of the position deployer contract
     */
    function _positionDeployer() internal view returns (address) {
        return IFactory(factory).positionDeployer();
    }
}
