// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IFactory} from "./interfaces/IFactory.sol";

/**
 * @title Position
 * @author Ibran Protocol
 * @notice A contract that manages lending positions with collateral and borrow assets
 * @dev This contract handles position management, token swapping, and collateral operations
 *
 * The Position contract represents a user's lending position in the Ibran protocol.
 * It manages collateral assets, borrow assets, and provides functionality for:
 * - Withdrawing collateral
 * - Swapping tokens within the position
 * - Repaying loans with selected tokens
 * - Calculating token values and exchange rates
 *
 * Key features:
 * - Reentrancy protection for secure operations
 * - Dynamic token list management
 * - Price oracle integration for accurate valuations
 * - Restricted access control (only lending pool can call certain functions)
 */
contract Position is ReentrancyGuard {
    using SafeERC20 for IERC20; // fungsi dari IERC20 akan ketambahan SafeERC20

    /// @notice Error thrown when there are insufficient tokens for an operation
    error InsufficientBalance();
    /// @notice Error thrown when attempting to process a zero amount
    error ZeroAmount();
    /// @notice Error thrown when a function is called by unauthorized address
    error NotForWithdraw();
    /// @notice Error thrown when a function is called by unauthorized address
    error NotForSwap();
    /// @notice Error thrown when a function is called by unauthorized address
    error TransferFailed();
    /// @notice The collateral token address for this position

    address public collateralAssets;
    /// @notice The borrow token address for this position
    address public borrowAssets;
    /// @notice The owner of this position
    address public owner;
    /// @notice The lending pool address that manages this position
    address public lpAddress;
    /// @notice The factory contract address
    address public factory;

    /// @notice Counter for tracking unique token IDs in the position's token list
    uint256 public counter;

    /// @notice Mapping from token ID to token address
    mapping(uint256 => address) public tokenLists;
    /// @notice Mapping from token address to token ID
    mapping(address => uint256) public tokenListsId;

    /// @notice Emitted when a position is liquidated
    /// @param user The address of the user whose position was liquidated
    event Liquidate(address user);

    /// @notice Emitted when tokens are swapped within the position
    /// @param user The address of the user performing the swap
    /// @param token The address of the token being swapped
    /// @param amount The amount of tokens being swapped
    event SwapToken(address user, address token, uint256 amount);

    /// @notice Emitted when tokens are swapped by the position contract
    /// @param user The address of the user initiating the swap
    /// @param tokenIn The address of the input token
    /// @param tokenOut The address of the output token
    /// @param amountIn The amount of input tokens
    /// @param amountOut The amount of output tokens received
    event SwapTokenByPosition(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /// @notice Emitted when collateral is withdrawn from the position
    /// @param user The address of the user withdrawing collateral
    /// @param amount The amount of collateral withdrawn
    event WithdrawCollateral(address indexed user, uint256 amount);

    /**
     * @notice Constructor to initialize a new position
     * @param _collateral The address of the collateral token
     * @param _borrow The address of the borrow token
     * @param _lpAddress The address of the lending pool
     * @param _factory The address of the factory contract
     * @dev Sets up the initial position with collateral and borrow assets
     */
    constructor(address _collateral, address _borrow, address _lpAddress, address _factory) {
        collateralAssets = _collateral;
        borrowAssets = _borrow;
        lpAddress = _lpAddress;
        factory = _factory;
        owner = msg.sender;
        ++counter;
        tokenLists[counter] = _collateral;
        tokenListsId[_collateral] = counter;
    }

    /**
     * @notice Modifier to check and register tokens in the position's token list
     * @param _token The address of the token to check
     * @dev Automatically adds new tokens to the position's token tracking system
     */
    modifier checkTokenList(address _token) {
        _checkTokenList(_token);
        _;
    }

    function _checkTokenList(address _token) internal {
        if (tokenListsId[_token] == 0) {
            ++counter;
            tokenLists[counter] = _token;
            tokenListsId[_token] = counter;
        }
    }

    /**
     * @notice Withdraws collateral from the position
     * @param amount The amount of collateral to withdraw
     * @param _user The address of the user to receive the collateral
     * @dev Only the lending pool can call this function
     * @dev Transfers collateral tokens to the specified user
     */
    function withdrawCollateral(uint256 amount, address _user) public {
        if (msg.sender != lpAddress) revert NotForWithdraw();
        if (collateralAssets == address(0)) {
            (bool sent,) = _user.call{value: amount}("");
            if (!sent) revert TransferFailed();
        } else {
            IERC20(collateralAssets).safeTransfer(_user, amount);
        }
        emit WithdrawCollateral(_user, amount);
    }

    /**
     * @notice Swaps tokens within the position using price oracles
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @return amountOut The amount of output tokens received
     * @dev Only the lending pool can call this function
     * @dev Uses PriceFeedIPriceFeed price feeds to calculate exchange rates
     * @dev Burns input tokens and mints output tokens
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 amountIn)
        public
        checkTokenList(_tokenIn)
        checkTokenList(_tokenOut)
        returns (uint256 amountOut)
    {
        uint256 balances = IERC20(_tokenIn).balanceOf(address(this));
        if (amountIn == 0) revert ZeroAmount();
        if (balances < amountIn) revert InsufficientBalance();
        if (msg.sender != owner) revert NotForSwap();

        // implement dragon swap

        emit SwapTokenByPosition(msg.sender, _tokenIn, _tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Repays a loan using a selected token
     * @param amount The amount to repay
     * @param _token The address of the token to use for repayment
     * @dev Only the lending pool can call this function
     * @dev If the selected token is not the borrow asset, it will be swapped first
     * @dev Any excess tokens after repayment are swapped back to the original token
     */
    function repayWithSelectedToken(uint256 amount, address _token) public payable {
        if (msg.sender != lpAddress) revert NotForWithdraw();
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (_token != borrowAssets) {
            uint256 amountOut = swapTokenByPosition(_token, borrowAssets, balance);
            IERC20(_token).approve(lpAddress, amount);
            if (borrowAssets == address(0)) {
                // transfer native token
                (bool sent,) = lpAddress.call{value: amount}("");
                if (!sent) revert TransferFailed();
            } else {
                IERC20(borrowAssets).safeTransfer(lpAddress, amount);
            }
            if (amountOut - amount != 0) swapTokenByPosition(borrowAssets, _token, (amountOut - amount));
        } else {
            if (borrowAssets == address(0)) {
                // transfer native token
                (bool sent,) = lpAddress.call{value: amount}("");
                if (!sent) revert TransferFailed();
            } else {
                IERC20(borrowAssets).safeTransfer(lpAddress, amount);
            }
        }
    }

    /**
     * @notice Calculates the output amount for a token swap based on price feeds
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens
     * @param _tokenInPrice The address of the input token's price feed
     * @param _tokenOutPrice The address of the output token's price feed
     * @return The calculated output amount
     * @dev Uses PriceFeedIPriceFeed price feeds to determine exchange rates
     * @dev Handles different token decimals automatically
     */
    function tokenCalculator(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _tokenInPrice,
        address _tokenOutPrice
    ) public view returns (uint256) {
        uint256 tokenInDecimal = IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = IERC20Metadata(_tokenOut).decimals();
        (, int256 quotePrice,,,) = IPriceFeed(_tokenInPrice).latestRoundData();
        (, int256 basePrice,,,) = IPriceFeed(_tokenOutPrice).latestRoundData();

        uint256 amountOut =
            (_amountIn * ((uint256(quotePrice) * (10 ** tokenOutDecimal)) / uint256(basePrice))) / 10 ** tokenInDecimal;

        return amountOut;
    }

    /**
     * @notice Calculates the USD value of a token balance in the position
     * @param token The address of the token to calculate value for
     * @return The USD value of the token balance (in 18 decimals)
     * @dev Uses PriceFeedIPriceFeed price feeds to get current token prices
     * @dev Returns value normalized to 18 decimals for consistency
     */
    function tokenValue(address token) public view returns (uint256) {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 tokenDecimals = IERC20Metadata(token).decimals();

        address tokenDataStream = IFactory(factory).tokenDataStream(token);

        (, int256 tokenPrice,,,) = IPriceFeed(tokenDataStream).latestRoundData();

        uint256 tokenAdjustedPrice = uint256(tokenPrice) * 1e18 / 1e8; // token standarize to 18 decimal, and divide by price decimals
        uint256 value = (tokenBalance * tokenAdjustedPrice) / (10 ** tokenDecimals);

        return value;
    }
}
