// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IFactory} from "./interfaces/IFactory.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPosition} from "./interfaces/IPosition.sol";

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title IsHealthy
 * @author Ibran Protocol
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
            if (token != address(0)) {  // Include all tokens, including KAIA (address(1))
                collateralValue += _tokenValue(addressPositions, token);
            }
        }
        uint256 borrowed = 0;
        borrowed = (userBorrowShares * totalBorrowAssets) / totalBorrowShares;
        uint256 borrowAdjustedPrice = uint256(borrowPrice) * 1e18 / 10 ** _oracleDecimal(factory, borrowToken);
        uint256 borrowValue = (borrowed * borrowAdjustedPrice) / (10 ** _tokenDecimals(borrowToken));

        // Calculate maximum allowed borrow based on LTV ratio
        uint256 maxBorrow = (collateralValue * ltv) / 1e18;

        // Validate position health
        if (borrowValue > collateralValue) revert InsufficientCollateral();
        if (borrowValue > maxBorrow) revert InsufficientCollateral();
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
