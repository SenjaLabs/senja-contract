// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFactory} from "./Interfaces/IFactory.sol";
import {IIsHealthy} from "./Interfaces/IIsHealthy.sol";
import {IPositionDeployer} from "./interfaces/IPositionDeployer.sol";

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
    /// @notice Error thrown when user has insufficient collateral
    error InsufficientCollateral();

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
    /// @notice Mapping of user to their collateral amount
    mapping(address => uint256) public userCollateral;
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

        amount = ((_shares * totalSupplyAssets) / totalSupplyShares);

        userSupplyShares[_user] -= _shares;
        totalSupplyShares -= _shares;
        totalSupplyAssets -= amount;

        if (totalSupplyAssets < totalBorrowAssets) {
            revert InsufficientLiquidity();
        }

        return amount;
    }

    function supplyCollateral(address _user, uint256 _amount) public onlyLendingPool {
        userCollateral[_user] += _amount;
    }

    function withdrawCollateral(uint256 _amount, address _user) public onlyLendingPool returns (uint256) {
        if (userCollateral[_user] < _amount) revert InsufficientCollateral();

        userCollateral[_user] -= _amount;

        if (userBorrowShares[_user] > 0) {
            address isHealthy = IFactory(factory).isHealthy();
            // ishealthy supply collateral
            IIsHealthy(isHealthy)._isHealthy(
                borrowToken,
                factory,
                addressPositions[_user],
                ltv,
                totalBorrowAssets,
                totalBorrowShares,
                userBorrowShares[_user]
            );
        }
        return userCollateral[_user];
    }

    /**
     * @dev Calculate dynamic borrow rate based on utilization rate
     * Similar to AAVE's interest rate model
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
        // Use dynamic interest rate based on utilization
        uint256 borrowRate = calculateBorrowRate();

        uint256 interestPerYear = (totalBorrowAssets * borrowRate) / 10000; // borrowRate is scaled by 100
        uint256 elapsedTime = block.timestamp - lastAccrued;
        uint256 interest = (interestPerYear * elapsedTime) / 365 days;

        // Reserve factor - portion of interest that goes to protocol
        uint256 reserveFactor = 1000; // 10% (scaled by 10000)
        uint256 reserveInterest = (interest * reserveFactor) / 10000;
        uint256 supplierInterest = interest - reserveInterest;

        totalSupplyAssets += supplierInterest;
        totalBorrowAssets += interest;
        lastAccrued = block.timestamp;
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

        protocolFee = (_amount * 1e15) / 1e18; // 0.1%
        userAmount = _amount - protocolFee;

        if (totalBorrowAssets > totalSupplyAssets) {
            revert InsufficientLiquidity();
        }
        address isHealthy = IFactory(factory).isHealthy();
        IIsHealthy(isHealthy)._isHealthy(
            borrowToken,
            factory,
            addressPositions[_user], // check position from other chain
            ltv,
            totalBorrowAssets,
            totalBorrowShares,
            userBorrowShares[_user]
        );

        return (protocolFee, userAmount, shares);
    }

    function repayWithSelectedToken(uint256 _shares, address _user)
        public
        onlyLendingPool
        returns (uint256, uint256, uint256, uint256)
    {
        if (_shares == 0) revert ZeroAmount();
        if (_shares > userBorrowShares[_user]) revert InsufficientShares();

        uint256 borrowAmount = ((_shares * totalBorrowAssets) / totalBorrowShares);
        userBorrowShares[_user] -= _shares;
        totalBorrowShares -= _shares;
        totalBorrowAssets -= borrowAmount;

        return (borrowAmount, userBorrowShares[_user], totalBorrowShares, totalBorrowAssets);
    }

    function createPosition(address _user) public onlyLendingPool returns (address) {
        if (addressPositions[_user] != address(0)) revert PositionAlreadyCreated();
        address position = IPositionDeployer(_positionDeployer()).deployPosition(lendingPool, _user);
        addressPositions[_user] = position;
        return position;
    }

    /**
     * @notice Gets the position deployer address from factory
     * @return The address of the position deployer contract
     */
    function _positionDeployer() internal view returns (address) {
        return IFactory(factory).positionDeployer();
    }

    /**
     * @notice Liquidates a user's position and resets borrow/collateral state
     * @param _user The address of the user being liquidated
     * @param _repayAmount The amount of debt being repaid
     * @dev This function resets user's borrow shares, collateral, and related variables
     * @dev User liquidity shares remain untouched as they're not related to borrowing
     */
    function liquidatePosition(address _user, uint256 _repayAmount) external {
        // Only allow calls from IsHealthy contract or authorized liquidators
        address isHealthyContract = IFactory(factory).isHealthy();
        require(msg.sender == isHealthyContract, "Not authorized");

        // Calculate shares to remove based on repay amount
        uint256 sharesToRemove = 0;
        if (totalBorrowAssets > 0 && totalBorrowShares > 0) {
            sharesToRemove = (_repayAmount * totalBorrowShares) / totalBorrowAssets;

            // Ensure we don't remove more shares than the user has
            if (sharesToRemove > userBorrowShares[_user]) {
                sharesToRemove = userBorrowShares[_user];
            }
        } else {
            // If no total borrow assets/shares, remove all user shares
            sharesToRemove = userBorrowShares[_user];
        }

        // Update user's borrow state
        userBorrowShares[_user] -= sharesToRemove;

        // Update total borrow state
        totalBorrowShares -= sharesToRemove;
        totalBorrowAssets -= _repayAmount;

        // Clear user's collateral (it's been seized in liquidation)
        userCollateral[_user] = 0;

        // Note: userSupplyShares[_user] is NOT touched - liquidity provision is separate from borrowing

        // Emit liquidation event (optional - can be handled by IsHealthy contract)
        emit PositionLiquidated(_user, sharesToRemove, _repayAmount);
    }

    /**
     * @notice Emergency function to completely reset a user's position
     * @param _user The address of the user whose position to reset
     * @dev Only callable by factory owner in emergency situations
     * @dev This resets ALL user state including liquidity (use with caution)
     */
    function emergencyResetPosition(address _user) external onlyFactory {
        userBorrowShares[_user] = 0;
        userCollateral[_user] = 0;
        // In emergency, also reset supply shares if needed
        // userSupplyShares[_user] = 0; // Uncomment if needed

        emit EmergencyPositionReset(_user);
    }

    /**
     * @notice Allows position contract to reduce user collateral during liquidation
     * @param _user The user whose collateral is being reduced
     * @param _amount The amount of collateral being removed
     * @dev Called by Position contract during collateral withdrawal for liquidation
     */
    function reduceUserCollateral(address _user, uint256 _amount) external {
        require(msg.sender == addressPositions[_user], "Not user's position");

        if (_amount > userCollateral[_user]) {
            userCollateral[_user] = 0;
        } else {
            userCollateral[_user] -= _amount;
        }
    }

    // Events for liquidation tracking
    /// @notice Emitted when a position is liquidated
    /// @param user The address of the user being liquidated
    /// @param sharesRemoved The amount of borrow shares removed
    /// @param debtRepaid The amount of debt repaid
    event PositionLiquidated(address indexed user, uint256 sharesRemoved, uint256 debtRepaid);

    /// @notice Emitted when a position is reset in emergency
    /// @param user The address of the user whose position was reset
    event EmergencyPositionReset(address indexed user);
}
