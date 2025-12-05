// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";
import {IWrappedNative} from "./interfaces/IWrappedNative.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";
import {ITokenDataStream} from "./interfaces/ITokenDataStream.sol";

/**
 * @title Position
 * @author Senja Protocol
 * @notice A contract that manages lending positions with collateral and borrow assets
 * @dev This contract handles position management, token swapping, and collateral operations
 *
 * The Position contract represents a user's lending position in the Senja protocol.
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
    /// @notice Error thrown when an invalid parameter is provided
    error InvalidParameter();
    /// @notice Error thrown when oracle on token is not set
    error OracleOnTokenNotSet();
    /// @notice Error thrown when a function is called by unauthorized address
    error OnlyForLendingPool();
    /// @notice Error thrown when the output amount is less than the minimum amount
    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMinimum);

    address public owner;
    address public lpAddress;
    uint256 public counter;

    // Track if we're in a withdrawal operation to avoid auto-wrapping
    bool private _withdrawing;

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
     * @param _lpAddress The address of the lending pool
     * @param _user The address of the user who owns this position
     * @dev Sets up the initial position with collateral and borrow assets
     */
    constructor(address _lpAddress, address _user) {
        lpAddress = _lpAddress;
        owner = _user;
        ++counter;
        tokenLists[counter] = _collateralToken();
        tokenListsId[_collateralToken()] = counter;
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
    modifier onlyLendingPool() {
        _onlyLendingPool();
        _;
    }

    /**
     * @notice Withdraws collateral from the position
     * @param amount The amount of collateral to withdraw
     * @param _user The address of the user to receive the collateral
     * @dev Only authorized contracts can call this function
     * @dev Transfers collateral tokens to the specified user
     */
    function withdrawCollateral(uint256 amount, address _user) public onlyLendingPool {
        if (amount == 0) revert ZeroAmount();
        _withdrawCollateralTransfer(amount, _user);
        emit WithdrawCollateral(_user, amount);
    }

    /**
     * @notice Swaps tokens within the position using DEX
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens to swap
     * @param _amountOutMinimum The minimum amount of output tokens received
     * @return amountOut The amount of output tokens received
     * @dev Only the position owner can call this function
     * @dev Uses DEX router for token swapping with slippage protection
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMinimum)
        public
        checkTokenList(_tokenIn)
        checkTokenList(_tokenOut)
        onlyLendingPool
        returns (uint256 amountOut)
    {
        if (IERC20(_tokenIn).balanceOf(address(this)) < _amountIn) revert InsufficientBalance();
        amountOut = _attemptDex(_tokenIn, _tokenOut, _amountIn, _amountOutMinimum);
        emit SwapTokenByPosition(msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
    }

    function swapTokenToBorrow(address _token, uint256 _amount, uint256 _amountOutMinimum) public onlyLendingPool {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 collateralNeeded = _calculateCollateralNeeded(_token, _borrowToken(), _amount);
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance < collateralNeeded) revert InsufficientBalance();
        uint256 amountOut =
            _attemptDex(_revealToken(_token), _revealToken(_borrowToken()), collateralNeeded, _amountOutMinimum);

        IERC20(_token).approve(lpAddress, amountOut);
        IERC20(_revealToken(_borrowToken())).safeTransfer(lpAddress, amountOut);
    }

    /**
     * @notice Repays a loan using a selected token
     * @param _token The address of the token to use for repayment
     * @param _amount The amount to repay
     * @param _amountOutMinimum The minimum amount of output tokens received
     * @dev Only authorized contracts can call this function
     * @dev If the selected token is not the borrow asset, it will be swapped first
     * @dev Any excess tokens after repayment are swapped back to the original token
     */
    function repayWithSelectedToken(address _token, uint256 _amount, uint256 _amountOutMinimum)
        public
        payable
        onlyLendingPool
    {
        if (_token != _borrowToken()) {
            uint256 collateralNeeded = _calculateCollateralNeeded(_token, _borrowToken(), _amount);
            uint256 balance = IERC20(_token).balanceOf(address(this));
            if (balance < collateralNeeded) revert InsufficientBalance();
            uint256 amountOut =
                _attemptDex(_revealToken(_token), _revealToken(_borrowToken()), collateralNeeded, _amountOutMinimum);

            IERC20(_token).approve(lpAddress, amountOut);
            IERC20(_revealToken(_borrowToken())).safeTransfer(lpAddress, amountOut);
        } else {
            IERC20(_token).approve(lpAddress, _amount);
            IERC20(_revealToken(_borrowToken())).safeTransfer(lpAddress, _amount);
        }
    }

    function liquidation(address _liquidator) public onlyLendingPool {
        owner = _liquidator;
        for (uint256 i = 1; i <= counter; i++) {
            address token = tokenLists[i];
            if (token == address(1)) {
                IERC20(_WRAPPED_NATIVE()).safeTransfer(_liquidator, IERC20(_WRAPPED_NATIVE()).balanceOf(address(this)));
            } else {
                IERC20(token).safeTransfer(_liquidator, IERC20(token).balanceOf(address(this)));
            }
        }
    }

    function totalCollateral() public view returns (uint256) {
        uint256 userCollateral = 0;
        for (uint256 i = 1; i <= counter; i++) {
            address token = tokenLists[i];
            userCollateral += _tokenCalculator(
                _revealToken(token),
                _revealToken(_collateralToken()),
                IERC20(_revealToken(token)).balanceOf(address(this))
            );
        }
        return userCollateral;
    }

    // =============================================================
    //                    INTERNAL HELPER FUNCTIONS
    // =============================================================

    function _router() internal view returns (address) {
        return ILendingPool(lpAddress).router();
    }

    function _factory() internal view returns (address) {
        return ILPRouter(_router()).factory();
    }

    function _collateralToken() internal view returns (address) {
        return ILPRouter(_router()).collateralToken();
    }

    function _borrowToken() internal view returns (address) {
        return ILPRouter(_router()).borrowToken();
    }

    function _tokenDataStream() internal view returns (address) {
        return IFactory(_factory()).tokenDataStream();
    }

    function _WRAPPED_NATIVE() internal view returns (address) {
        return IFactory(_factory()).WRAPPED_NATIVE();
    }

    function _DEX_ROUTER() internal view returns (address) {
        return IFactory(_factory()).DEX_ROUTER();
    }

    function _totalBorrowAssets() internal view returns (uint256) {
        return ILPRouter(_router()).totalBorrowAssets();
    }

    /**
     * @notice Calculates the output amount for a token swap based on price feeds
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens
     * @return Calculated output amount
     * @dev Uses PriceFeedIOracle price feeds to determine exchange rates
     * @dev Handles different token decimals automatically
     */

    function _tokenCalculator(address _tokenIn, address _tokenOut, uint256 _amountIn) public view returns (uint256) {
        uint256 tokenInDecimal = _tokenDecimals(_tokenIn);
        uint256 tokenOutDecimal = _tokenDecimals(_tokenOut);
        uint256 quotePrice = _tokenPrice(_tokenIn);
        uint256 basePrice = _tokenPrice(_tokenOut);

        uint256 amountOut =
            (_amountIn * ((uint256(quotePrice) * (10 ** tokenOutDecimal)) / uint256(basePrice))) / 10 ** tokenInDecimal;

        return amountOut;
    }

    function _withdrawCollateralTransfer(uint256 amount, address _user) internal {
        if (_collateralToken() == address(1)) {
            _withdrawing = true;
            IERC20(_WRAPPED_NATIVE()).approve(_WRAPPED_NATIVE(), amount);
            IWrappedNative(_WRAPPED_NATIVE()).withdraw(amount);
            (bool sent,) = _user.call{value: amount}("");
            if (!sent) revert TransferFailed();
            _withdrawing = false;
        } else {
            IERC20(_collateralToken()).safeTransfer(_user, amount);
        }
    }

    function _calculateCollateralNeeded(address _collateral, address _borrow, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        uint256 borrowPrice = _tokenPrice(_borrow);
        uint256 collateralPrice = _tokenPrice(_collateral);
        uint256 borrowDecimal = _tokenDecimals(_revealToken(_borrow));
        uint256 collateralDecimal = _tokenDecimals(_revealToken(_collateral));
        uint256 collateralNeeded =
            (_amount * borrowPrice * (10 ** collateralDecimal)) / (collateralPrice * (10 ** borrowDecimal));
        return collateralNeeded;
    }

    // =============================================================
    // =============================================================

    /**
     * @notice Attempts DEX with slippage protection
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens to swap
     * @param _amountOutMinimum The minimum amount of output tokens received
     * @return amountOut The amount of output tokens received
     */
    function _attemptDex(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMinimum)
        internal
        returns (uint256 amountOut)
    {
        IERC20(_tokenIn).approve(_DEX_ROUTER(), _amountIn);
        IDexRouter.ExactInputSingleParams memory params = IDexRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _revealToken(_tokenOut),
            fee: 1000, // 0.1% fee tier
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes deadline
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMinimum, // Slippage protection
            sqrtPriceLimitX96: 0 // No price limit
        });

        amountOut = IDexRouter(_DEX_ROUTER()).exactInputSingle(params);
        if (amountOut < _amountOutMinimum) revert InsufficientOutputAmount(amountOut, _amountOutMinimum);
        return amountOut;
    }

    function _checkTokenList(address _token) internal {
        if (tokenListsId[_token] == 0) {
            ++counter;
            tokenLists[counter] = _token;
            tokenListsId[_token] = counter;
        }
    }

    function _onlyLendingPool() internal view {
        if (msg.sender != lpAddress) revert OnlyForLendingPool();
    }

    function _tokenPrice(address _token) internal view returns (uint256) {
        (, uint256 price,,,) = ITokenDataStream(_tokenDataStream()).latestRoundData(_token);
        return price;
    }

    /// @notice Gets the number of decimals used by an ERC20 token
    /// @dev Used to properly normalize token amounts for value calculations
    /// @param _token The token address to get decimals for
    /// @return The number of decimals used by the ERC20 token
    function _tokenDecimals(address _token) internal view returns (uint256) {
        if (_token == _WRAPPED_NATIVE()) {
            return 18;
        }
        return IERC20Metadata(_token).decimals();
    }

    function _revealToken(address _token) internal view returns (address) {
        if (_token == address(1)) {
            return _WRAPPED_NATIVE();
        }
        return _token;
    }

    /**
     * @notice Allows the contract to receive native tokens and automatically wraps them to Wrapped Native
     * @dev Required for native token collateral functionality
     * @dev Avoids infinite loop when Wrapped Native contract sends native tokens during withdrawal
     */
    receive() external payable {
        // Only wrap if this position handles native tokens and not during withdrawal
        if (msg.value > 0 && !_withdrawing && _collateralToken() == address(1)) {
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
        } else if (msg.value > 0 && _withdrawing) {
            // During withdrawal, accept native tokens without wrapping
            return;
        } else if (msg.value > 0) {
            // Unexpected native token for non-native position
            revert("Position does not handle native tokens");
        }
    }

    fallback() external payable {
        // Fallback should not accept native tokens to prevent accidental loss
        revert("Fallback not allowed");
    }
}
