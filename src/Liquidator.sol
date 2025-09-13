// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IDragonSwap} from "./interfaces/IDragonSwap.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title Liquidator
 * @author Ibran Protocol
 * @notice A contract that handles liquidation of unhealthy lending positions
 * @dev This contract provides both DEX and MEV liquidation options
 */
contract Liquidator is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // DragonSwap router address on Kaia mainnet
    address public constant DRAGON_SWAP_ROUTER = 0xA324880f884036E3d21a09B90269E1aC57c7EC8a;

    error NotLiquidatable();
    error LiquidationFailed();
    error InsufficientPayment();
    error TransferFailed();

    address public factory;

    constructor() Ownable(msg.sender) {
    }

    /**
     * @notice Emitted when a position is liquidated
     * @param borrower The address of the borrower being liquidated
     * @param liquidator The address of the liquidator
     * @param collateralAmount Amount of collateral liquidated
     * @param debtAmount Amount of debt repaid
     * @param liquidationType Type of liquidation (0 = DEX, 1 = MEV)
     */
    event PositionLiquidated(
        address indexed borrower,
        address indexed liquidator,
        uint256 collateralAmount,
        uint256 debtAmount,
        uint256 liquidationType
    );

    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    /**
     * @notice Liquidates a position using DEX (DragonSwap)
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param liquidationIncentive The liquidation incentive in basis points (e.g., 500 = 5%)
     * @return liquidatedAmount Amount of debt repaid
     */
    function liquidateByDEX(
        address borrower,
        address lendingPoolRouter,
        uint256 liquidationIncentive
    ) external nonReentrant returns (uint256 liquidatedAmount) {
        // Validate liquidation eligibility
        address borrowerPosition = ILPRouter(lendingPoolRouter).addressPositions(borrower);
        require(borrowerPosition != address(0), "No position found");

        // Check if position is liquidatable
        (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue) = _checkLiquidation(
            borrower,
            lendingPoolRouter,
            borrowerPosition
        );

        if (!isLiquidatable) revert NotLiquidatable();

        // Execute DEX liquidation
        (uint256 collateralToLiquidate, uint256 actualLiquidatedAmount) = _executeDEXLiquidation(
            borrower,
            lendingPoolRouter,
            borrowerPosition,
            borrowValue,
            collateralValue,
            liquidationIncentive
        );

        liquidatedAmount = actualLiquidatedAmount;
        emit PositionLiquidated(borrower, msg.sender, collateralToLiquidate, liquidatedAmount, 0);
    }

    /**
     * @notice Liquidates a position using MEV (external liquidator buys collateral)
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param repayAmount Amount of debt the liquidator wants to repay
     * @param liquidationIncentive The liquidation incentive in basis points
     */
    function liquidateByMEV(
        address borrower,
        address lendingPoolRouter,
        uint256 repayAmount,
        uint256 liquidationIncentive
    ) external payable nonReentrant {
        // Validate liquidation eligibility
        address borrowerPosition = ILPRouter(lendingPoolRouter).addressPositions(borrower);
        require(borrowerPosition != address(0), "No position found");

        // Check if position is liquidatable
        (bool isLiquidatable,,) = _checkLiquidation(
            borrower,
            lendingPoolRouter,
            borrowerPosition
        );

        if (!isLiquidatable) revert NotLiquidatable();

        // Execute MEV liquidation
        uint256 collateralValue = _executeMEVLiquidation(
            borrower,
            lendingPoolRouter,
            borrowerPosition,
            repayAmount,
            liquidationIncentive
        );

        emit PositionLiquidated(borrower, msg.sender, collateralValue, repayAmount, 1);
    }

    /**
     * @notice Checks if a position is liquidatable
     */
    function _checkLiquidation(
        address borrower,
        address lendingPoolRouter,
        address borrowerPosition
    ) internal view returns (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue) {
        address borrowToken = ILPRouter(lendingPoolRouter).borrowToken();
        uint256 ltv = ILPRouter(lendingPoolRouter).ltv();
        uint256 totalBorrowAssets = ILPRouter(lendingPoolRouter).totalBorrowAssets();
        uint256 totalBorrowShares = ILPRouter(lendingPoolRouter).totalBorrowShares();
        uint256 userBorrowShares = ILPRouter(lendingPoolRouter).userBorrowShares(borrower);

        // Get prices and values
        (, uint256 borrowPrice,,,) = IOracle(_tokenDataStream(borrowToken)).latestRoundData();
        
        collateralValue = 0;
        for (uint256 i = 1; i <= _counter(borrowerPosition); i++) {
            address token = IPosition(borrowerPosition).tokenLists(i);
            if (token != address(0)) {
                collateralValue += _tokenValue(borrowerPosition, token);
            }
        }

        uint256 borrowed = (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
        uint256 borrowAdjustedPrice = uint256(borrowPrice) * 1e18 / 10 ** _oracleDecimal(borrowToken);
        borrowValue = (borrowed * borrowAdjustedPrice) / (10 ** _tokenDecimals(borrowToken));

        uint256 maxBorrow = (collateralValue * ltv) / 1e18;
        
        isLiquidatable = (borrowValue > collateralValue) || (borrowValue > maxBorrow);
    }

    /**
     * @notice Executes DEX liquidation
     */
    function _executeDEXLiquidation(
        address borrower,
        address lendingPoolRouter,
        address borrowerPosition,
        uint256 borrowValue,
        uint256 collateralValue,
        uint256 liquidationIncentive
    ) internal returns (uint256 collateralToLiquidate, uint256 liquidatedAmount) {
        // Calculate liquidation amounts and get token addresses
        (collateralToLiquidate, liquidatedAmount) = _calculateAndExecuteSwap(
            borrower,
            lendingPoolRouter,
            borrowerPosition,
            borrowValue,
            collateralValue,
            liquidationIncentive
        );
    }

    /**
     * @notice Calculates liquidation amounts and executes swap
     */
    function _calculateAndExecuteSwap(
        address borrower,
        address lendingPoolRouter,
        address borrowerPosition,
        uint256 borrowValue,
        uint256 collateralValue,
        uint256 liquidationIncentive
    ) internal returns (uint256 collateralToLiquidate, uint256 liquidatedAmount) {
        // Get token addresses
        address borrowToken = ILPRouter(lendingPoolRouter).borrowToken();
        address collateralToken = ILPRouter(lendingPoolRouter).collateralToken();
        
        // Calculate debt to liquidate (max 50% of collateral)
        uint256 debtToLiquidate = borrowValue > (collateralValue * 5000) / 10000 
            ? (collateralValue * 5000) / 10000 
            : borrowValue;
        
        // Execute the liquidation process
        (collateralToLiquidate, liquidatedAmount) = _processLiquidation(
            borrower,
            lendingPoolRouter,
            borrowerPosition,
            borrowToken,
            collateralToken,
            debtToLiquidate,
            liquidationIncentive
        );
    }

    /**
     * @notice Processes the actual liquidation steps
     */
    function _processLiquidation(
        address borrower,
        address lendingPoolRouter,
        address borrowerPosition,
        address borrowToken,
        address collateralToken,
        uint256 debtToLiquidate,
        uint256 liquidationIncentive
    ) internal returns (uint256 collateralToLiquidate, uint256 liquidatedAmount) {
        // Get effective collateral token and validate
        address effectiveCollateralToken = collateralToken == address(1) ? _WKAIA() : collateralToken;
        uint256 totalCollateral = IERC20(effectiveCollateralToken).balanceOf(borrowerPosition);
        
        if (totalCollateral == 0) revert LiquidationFailed();

        // Calculate collateral amount with incentive
        collateralToLiquidate = (debtToLiquidate * (10000 + liquidationIncentive)) / 10000;
        if (collateralToLiquidate > totalCollateral) {
            collateralToLiquidate = totalCollateral;
        }

        // Execute swap and repayment
        liquidatedAmount = _executeSwapAndRepay(
            borrower,
            lendingPoolRouter,
            borrowerPosition,
            borrowToken,
            effectiveCollateralToken,
            collateralToLiquidate,
            debtToLiquidate
        );
    }

    /**
     * @notice Executes the swap and debt repayment
     */
    function _executeSwapAndRepay(
        address borrower,
        address lendingPoolRouter,
        address borrowerPosition,
        address borrowToken,
        address effectiveCollateralToken,
        uint256 collateralToLiquidate,
        uint256 debtToLiquidate
    ) internal returns (uint256 actualLiquidatedAmount) {
        // Transfer collateral from position to this contract
        IPosition(borrowerPosition).withdrawCollateral(collateralToLiquidate, address(this), false);

        // Swap collateral to borrow token
        uint256 amountOut = _performDragonSwap(
            effectiveCollateralToken,
            borrowToken == address(1) ? _WKAIA() : borrowToken,
            collateralToLiquidate,
            1000 // 10% slippage tolerance
        );

        // Calculate actual liquidated amount
        actualLiquidatedAmount = amountOut > debtToLiquidate ? debtToLiquidate : amountOut;
        
        // Get effective borrow token for transfers
        address effectiveBorrowToken = borrowToken == address(1) ? _WKAIA() : borrowToken;

        // Repay debt to lending pool
        IERC20(effectiveBorrowToken).safeTransfer(lendingPoolRouter, actualLiquidatedAmount);

        // Reset borrower state in router
        ILPRouter(lendingPoolRouter).liquidatePosition(borrower, actualLiquidatedAmount);

        // Transfer any remaining tokens to protocol
        if (amountOut > actualLiquidatedAmount) {
            IERC20(effectiveBorrowToken).safeTransfer(
                IFactory(factory).protocol(),
                amountOut - actualLiquidatedAmount
            );
        }
    }

    /**
     * @notice Executes MEV liquidation
     */
    function _executeMEVLiquidation(
        address borrower,
        address lendingPoolRouter,
        address borrowerPosition,
        uint256 repayAmount,
        uint256 liquidationIncentive
    ) internal returns (uint256 collateralValue) {
        address borrowToken = ILPRouter(lendingPoolRouter).borrowToken();
        address collateralToken = ILPRouter(lendingPoolRouter).collateralToken();

        // Calculate collateral amount to give to liquidator
        collateralValue = _calculateCollateralForDebt(
            borrowToken,
            collateralToken,
            repayAmount,
            liquidationIncentive
        );

        // Get available collateral and cap if necessary
        address effectiveToken = collateralToken == address(1) ? _WKAIA() : collateralToken;
        uint256 availableCollateral = IERC20(effectiveToken).balanceOf(borrowerPosition);
        
        if (collateralValue > availableCollateral) {
            collateralValue = availableCollateral;
        }

        // Handle payment from liquidator
        if (borrowToken == address(1)) {
            if (msg.value < repayAmount) revert InsufficientPayment();
            if (msg.value > repayAmount) {
                // Refund excess
                (bool sent,) = msg.sender.call{value: msg.value - repayAmount}("");
                if (!sent) revert TransferFailed();
            }
        } else {
            IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        }

        // Transfer collateral to liquidator
        IPosition(borrowerPosition).withdrawCollateral(
            collateralValue, 
            msg.sender, 
            collateralToken == address(1)
        );

        // Repay debt to lending pool
        if (borrowToken == address(1)) {
            (bool sent,) = lendingPoolRouter.call{value: repayAmount}("");
            if (!sent) revert TransferFailed();
        } else {
            IERC20(borrowToken).safeTransfer(lendingPoolRouter, repayAmount);
        }

        // Reset borrower state in router
        ILPRouter(lendingPoolRouter).liquidatePosition(borrower, repayAmount);
    }

    /**
     * @notice Performs token swap using DragonSwap
     */
    function _performDragonSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 amountIn,
        uint256 slippageTolerance
    ) internal returns (uint256 amountOut) {
        // Calculate expected amount and minimum output
        uint256 expectedAmount = _calculateExpectedAmount(_tokenIn, _tokenOut, amountIn);
        uint256 amountOutMinimum = expectedAmount * (10000 - slippageTolerance) / 10000;

        // Approve DragonSwap router
        IERC20(_tokenIn).approve(DRAGON_SWAP_ROUTER, amountIn);

        // Prepare swap parameters
        IDragonSwap.ExactInputSingleParams memory params = IDragonSwap.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: 1000, // 0.1% fee tier
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes deadline
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        // Perform the swap
        amountOut = IDragonSwap(DRAGON_SWAP_ROUTER).exactInputSingle(params);
    }

    /**
     * @notice Calculates expected amount for token swap
     */
    function _calculateExpectedAmount(
        address _tokenIn,
        address _tokenOut,
        uint256 amountIn
    ) internal pure returns (uint256 expectedAmount) {
        // Simple calculation - in production should use proper price feeds
        if (_tokenIn != _tokenOut) {
            // For WKAIA to USDT conversion (example)
            if (_tokenOut == 0xd077A400968890Eacc75cdc901F0356c943e4fDb) {
                expectedAmount = (amountIn * 157) / (1000 * 1e12);
            } else {
                expectedAmount = amountIn;
            }
        } else {
            expectedAmount = amountIn;
        }
    }

    /**
     * @notice Calculates collateral amount for given debt repayment
     */
    function _calculateCollateralForDebt(
        address borrowToken,
        address collateralToken,
        uint256 debtAmount,
        uint256 liquidationIncentive
    ) internal view returns (uint256 collateralAmount) {
        // Get prices
        (, uint256 borrowPrice,,,) = IOracle(_tokenDataStream(borrowToken)).latestRoundData();
        (, uint256 collateralPrice,,,) = IOracle(_tokenDataStream(collateralToken == address(1) ? _WKAIA() : collateralToken)).latestRoundData();

        // Calculate base collateral amount
        uint256 borrowDecimals = _tokenDecimals(borrowToken);
        uint256 collateralDecimals = _tokenDecimals(collateralToken);
        
        uint256 debtValueUSD = (debtAmount * borrowPrice) / (10 ** borrowDecimals);
        uint256 baseCollateralAmount = (debtValueUSD * (10 ** collateralDecimals)) / collateralPrice;
        
        // Add liquidation incentive
        collateralAmount = (baseCollateralAmount * (10000 + liquidationIncentive)) / 10000;
    }

    // Helper functions
    function _tokenDecimals(address _token) internal view returns (uint8) {
        return _token == address(1) ? 18 : IERC20Metadata(_token).decimals();
    }

    function _oracleDecimal(address _token) internal view returns (uint8) {
        return IOracle(_tokenDataStream(_token)).decimals();
    }

    function _tokenDataStream(address _token) internal view returns (address) {
        return IFactory(factory).tokenDataStream(_token);
    }

    function _counter(address addressPositions) internal view returns (uint256) {
        return IPosition(addressPositions).counter();
    }

    function _tokenValue(address addressPositions, address token) internal view returns (uint256) {
        return IPosition(addressPositions).tokenValue(token);
    }

    function _WKAIA() internal view returns (address) {
        return IFactory(factory).WKAIA();
    }

    // Allow contract to receive native tokens
    receive() external payable {}
}
