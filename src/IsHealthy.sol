// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IFactory} from "./interfaces/IFactory.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPosition} from "./interfaces/IPosition.sol";

/**
 * @title IsHealthy
 * @author Senja Protocol
 * @notice A contract that validates the health status of lending positions
 * @dev This contract checks if a user's position is healthy by comparing
 *      the total collateral value against the borrowed amount and LTV ratio
 *
 * The health check ensures:
 * - The borrowed value doesn't exceed the total collateral value
 * - The borrowed value doesn't exceed the maximum allowed based on LTV ratio
 *
 * @custom:security This contract is used for position validation and should be
 *                  called before allowing additional borrows or liquidations
 */
contract IsHealthy {
    /**
     * @notice Error thrown when the position has insufficient collateral
     * @dev This error is thrown when either:
     *      - The borrowed value exceeds the total collateral value
     *      - The borrowed value exceeds the maximum allowed based on LTV ratio
     */
    error InsufficientCollateral();

    /**
     * @notice Address of the Liquidator contract
     */
    address public liquidator;

    /**
     * @notice Constructor to set the liquidator contract address
     * @param _liquidator Address of the Liquidator contract
     */
    constructor(address _liquidator) {
        liquidator = _liquidator;
    }

    /**
     * @notice Validates if a user's lending position is healthy
     * @dev This function performs a comprehensive health check by:
     *      1. Fetching the current price of the borrowed token from Chainlink
     *      2. Calculating the total collateral value from all user positions
     *      3. Computing the actual borrowed amount in the borrowed token
     *      4. Converting the borrowed amount to USD value
     *      5. Comparing against collateral value and LTV limits
     *
     * @param borrowToken The address of the token being borrowed
     * @param factory The address of the lending pool factory contract
     * @param addressPositions The address of the positions contract
     * @param ltv The loan-to-value ratio (in basis points, e.g., 8000 = 80%)
     * @param totalBorrowAssets The total amount of assets borrowed across all users
     * @param totalBorrowShares The total number of borrow shares across all users
     * @param userBorrowShares The number of borrow shares owned by the user
     *
     * @custom:revert InsufficientCollateral When the position is unhealthy
     *
     * @custom:security This function should be called before any borrow operations
     *                  to ensure the position remains healthy after the operation
     */
    function _isHealthy(
        address borrowToken,
        address factory,
        address addressPositions,
        uint256 ltv,
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 userBorrowShares
    ) public view {
        (, uint256 borrowPrice,,,) = IOracle(_tokenDataStream(factory, borrowToken)).latestRoundData();
        uint256 collateralValue = 0;
        for (uint256 i = 1; i <= _counter(addressPositions); i++) {
            address token = IPosition(addressPositions).tokenLists(i);
            if (token != address(0)) {
                collateralValue += _tokenValue(addressPositions, token);
            }
        }
        uint256 borrowed = 0;
        borrowed = (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
        uint256 borrowAdjustedPrice = uint256(borrowPrice) * 1e18 / 10 ** _oracleDecimal(factory, borrowToken);
        uint256 borrowValue = (borrowed * borrowAdjustedPrice) / (10 ** _tokenDecimals(borrowToken));

        // Calculate maximum allowed borrow based on LTV ratio
        uint256 maxBorrow = (collateralValue * ltv) / 1e18;

        // Check if position needs liquidation
        bool isLiquidatable = (borrowValue > collateralValue) || (borrowValue > maxBorrow);

        if (isLiquidatable) {
            // Position is unhealthy and should be liquidated
            revert InsufficientCollateral();
        }
    }

    /**
     * @notice Checks if a position is liquidatable
     * @param borrowToken The address of the token being borrowed
     * @param factory The address of the lending pool factory contract
     * @param addressPositions The address of the positions contract
     * @param ltv The loan-to-value ratio
     * @param totalBorrowAssets The total amount of assets borrowed across all users
     * @param totalBorrowShares The total number of borrow shares across all users
     * @param userBorrowShares The number of borrow shares owned by the user
     * @return isLiquidatable Whether the position can be liquidated
     * @return borrowValue The current borrow value in USD
     * @return collateralValue The current collateral value in USD
     */
    function checkLiquidation(
        address borrowToken,
        address factory,
        address addressPositions,
        uint256 ltv,
        uint256 totalBorrowAssets,
        uint256 totalBorrowShares,
        uint256 userBorrowShares
    ) public view returns (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue) {
        (, uint256 borrowPrice,,,) = IOracle(_tokenDataStream(factory, borrowToken)).latestRoundData();

        collateralValue = 0;
        for (uint256 i = 1; i <= _counter(addressPositions); i++) {
            address token = IPosition(addressPositions).tokenLists(i);
            if (token != address(0)) {
                collateralValue += _tokenValue(addressPositions, token);
            }
        }

        uint256 borrowed = (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
        uint256 borrowAdjustedPrice = uint256(borrowPrice) * 1e18 / 10 ** _oracleDecimal(factory, borrowToken);
        borrowValue = (borrowed * borrowAdjustedPrice) / (10 ** _tokenDecimals(borrowToken));

        uint256 maxBorrow = (collateralValue * ltv) / 1e18;

        isLiquidatable = (borrowValue > collateralValue) || (borrowValue > maxBorrow);
    }

    /**
     * @notice Liquidates a position using DEX (calls Liquidator contract)
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param // factory The address of the factory
     * @param liquidationIncentive The liquidation incentive in basis points
     * @return liquidatedAmount Amount of debt repaid
     */
    function liquidateByDEX(
        address borrower,
        address lendingPoolRouter,
        address, /* factory */
        uint256 liquidationIncentive
    ) external returns (uint256 liquidatedAmount) {
        // Use regular call instead of delegatecall for security
        (bool success, bytes memory data) = liquidator.call(
            abi.encodeWithSignature(
                "liquidateByDEX(address,address,uint256)", borrower, lendingPoolRouter, liquidationIncentive
            )
        );
        require(success, "Liquidation failed");
        liquidatedAmount = abi.decode(data, (uint256));
    }

    /**
     * @notice Liquidates a position using MEV (calls Liquidator contract)
     * @param borrower The address of the borrower to liquidate
     * @param lendingPoolRouter The address of the lending pool router
     * @param // factory The address of the factory
     * @param repayAmount Amount of debt the liquidator wants to repay
     * @param liquidationIncentive The liquidation incentive in basis points
     */
    function liquidateByMEV(
        address borrower,
        address lendingPoolRouter,
        address, /* factory */
        uint256 repayAmount,
        uint256 liquidationIncentive
    ) external payable {
        // Use regular call instead of delegatecall for security
        (bool success,) = liquidator.call{value: msg.value}(
            abi.encodeWithSignature(
                "liquidateByMEV(address,address,uint256,uint256)",
                borrower,
                lendingPoolRouter,
                repayAmount,
                liquidationIncentive
            )
        );
        require(success, "Liquidation failed");
    }

    function _tokenDecimals(address _token) internal view returns (uint8) {
        return _token == address(1) ? 18 : IERC20Metadata(_token).decimals();
    }

    function _oracleDecimal(address factory, address _token) internal view returns (uint8) {
        return IOracle(_tokenDataStream(factory, _token)).decimals();
    }

    function _tokenDataStream(address factory, address _token) internal view returns (address) {
        return IFactory(factory).tokenDataStream(_token);
    }

    function _counter(address addressPositions) internal view returns (uint256) {
        return IPosition(addressPositions).counter();
    }

    function _tokenValue(address addressPositions, address token) internal view returns (uint256) {
        return IPosition(addressPositions).tokenValue(token);
    }
}
