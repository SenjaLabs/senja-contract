// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IDexRouter} from "./interfaces/IDexRouter.sol";
import {IWrappedNative} from "./interfaces/IWrappedNative.sol";
import {ITokenDataStream} from "./interfaces/ITokenDataStream.sol";

/**
 * @title Position
 * @author Senja Labs
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

    // =============================================================
    //                           ERRORS
    // =============================================================

    /**
     * @notice Error thrown when there are insufficient tokens for an operation
     */
    error InsufficientBalance();

    /**
     * @notice Error thrown when attempting to process a zero amount
     */
    error ZeroAmount();

    /**
     * @notice Error thrown when a withdrawal operation is not authorized
     */
    error NotForWithdraw();

    /**
     * @notice Error thrown when a swap operation is not authorized
     */
    error NotForSwap();

    /**
     * @notice Error thrown when a native token transfer fails
     */
    error TransferFailed();

    /**
     * @notice Error thrown when an invalid parameter is provided
     */
    error InvalidParameter();

    /**
     * @notice Error thrown when oracle on token is not set
     */
    error OracleOnTokenNotSet();

    /**
     * @notice Error thrown when a function is called by unauthorized address
     */
    error OnlyForLendingPool();

    /**
     * @notice Error thrown when the output amount is less than the minimum amount
     * @param amountOut The actual output amount received
     * @param amountOutMinimum The minimum expected output amount
     */
    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMinimum);

    // =============================================================
    //                       STATE VARIABLES
    // =============================================================

    /// @notice The address of the position owner
    address public owner;

    /// @notice The address of the lending pool contract
    address public lpAddress;

    /// @notice Counter for tracking the number of unique tokens in the position
    uint256 public counter;

    /// @dev Track if we're in a withdrawal operation to avoid auto-wrapping native tokens
    bool private _withdrawing;

    /// @notice Mapping from token ID to token address
    mapping(uint256 => address) public tokenLists;

    /// @notice Mapping from token address to token ID
    mapping(address => uint256) public tokenListsId;

    // =============================================================
    //                           EVENTS
    // =============================================================

    /**
     * @notice Emitted when a position is liquidated
     * @param user The address of the user whose position was liquidated
     */
    event Liquidate(address user);

    /**
     * @notice Emitted when tokens are swapped within the position
     * @param user The address of the user performing the swap
     * @param token The address of the token being swapped
     * @param amount The amount of tokens being swapped
     */
    event SwapToken(address user, address token, uint256 amount);

    /**
     * @notice Emitted when tokens are swapped by the position contract
     * @param user The address of the user initiating the swap
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @param amountOut The amount of output tokens received
     */
    event SwapTokenByPosition(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Emitted when collateral is withdrawn from the position
     * @param user The address of the user withdrawing collateral
     * @param amount The amount of collateral withdrawn
     */
    event WithdrawCollateral(address indexed user, uint256 amount);

    // =============================================================
    //                        CONSTRUCTOR
    // =============================================================

    /**
     * @notice Constructor to initialize a new position
     * @param _lpAddress The address of the lending pool contract
     * @param _user The address of the user who owns this position
     * @dev Sets up the initial position with collateral token registered in the token list
     * @dev Increments counter and registers the collateral token as the first token in the list
     */
    constructor(address _lpAddress, address _user) {
        lpAddress = _lpAddress;
        owner = _user;
        ++counter;
        tokenLists[counter] = _collateralToken();
        tokenListsId[_collateralToken()] = counter;
    }

    // =============================================================
    //                         MODIFIERS
    // =============================================================

    /**
     * @notice Modifier to check and register tokens in the position's token list
     * @param _token The address of the token to check
     * @dev Automatically adds new tokens to the position's token tracking system if not already registered
     */
    modifier checkTokenList(address _token) {
        _checkTokenList(_token);
        _;
    }

    /**
     * @notice Modifier to restrict function access to the lending pool only
     * @dev Reverts with OnlyForLendingPool if caller is not the lending pool
     */
    modifier onlyLendingPool() {
        _onlyLendingPool();
        _;
    }

    // =============================================================
    //                    EXTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Withdraws collateral from the position
     * @param amount The amount of collateral to withdraw
     * @param _user The address of the user to receive the collateral
     * @dev Only the lending pool can call this function
     * @dev Transfers collateral tokens to the specified user
     * @dev Handles both ERC20 tokens and native tokens (unwraps if necessary)
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
     * @param _amountOutMinimum The minimum amount of output tokens expected (slippage protection)
     * @return amountOut The actual amount of output tokens received
     * @dev Only the lending pool can call this function
     * @dev Uses DEX router for token swapping with slippage protection
     * @dev Automatically registers both tokens in the position's token list
     * @dev Reverts if insufficient balance or output amount is below minimum
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

    /**
     * @notice Swaps a token to the borrow token via DEX
     * @param _token The address of the token to swap from
     * @param _amount The amount to swap
     * @param _amountOutMinimum The minimum amount of borrow token expected (slippage protection)
     * @dev Only the lending pool can call this function
     * @dev Transfers token from caller, calculates collateral needed, performs swap, and sends borrow token to lending pool
     * @dev Approves lending pool to spend the swapped borrow tokens
     */
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
     * @param _amountOutMinimum The minimum amount of borrow token expected after swap (slippage protection)
     * @dev Only the lending pool can call this function
     * @dev If the selected token is not the borrow asset, it will be swapped first
     * @dev Approves lending pool to spend the borrow tokens and transfers them
     * @dev Handles both direct repayment and swap-then-repay scenarios
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

    /**
     * @notice Liquidates the position and transfers all tokens to the liquidator
     * @param _liquidator The address of the liquidator who will receive all tokens
     * @param _liquidationBonus The amount of liquidation bonus to be transferred to the liquidator
     * @dev Only the lending pool can call this function
     * @dev Transfers ownership to the liquidator
     * @dev Iterates through all tokens in the position and transfers their balances
     * @dev Handles both wrapped native tokens and regular ERC20 tokens
     */
    function liquidation(address _liquidator, uint256 _liquidationBonus) public onlyLendingPool {
        for (uint256 i = 1; i <= counter; i++) {
            address token = tokenLists[i];
            uint256 balance = IERC20(_revealToken(token)).balanceOf(address(this));
            uint256 toLiquidator = (balance * (1e18 - _liquidationBonus)) / 1e18;
            uint256 toProtocol = (balance * _liquidationBonus) / 1e18;

            IERC20(_revealToken(token)).safeTransfer(_liquidator, toLiquidator);
            IERC20(_revealToken(token)).safeTransfer(_protocol(), toProtocol);
        }
        owner = _liquidator;
    }

    /**
     * @notice Calculates the total collateral value in the position
     * @return The total collateral value denominated in the collateral token
     * @dev Iterates through all tokens in the position
     * @dev Converts each token balance to collateral token value using price oracles
     * @dev Sums up all token values to get total collateral
     */
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

    /**
     * @notice Gets the router address from the lending pool
     * @return The address of the lending pool router
     * @dev Internal function to retrieve router configuration
     */
    function _router() internal view returns (address) {
        return ILendingPool(lpAddress).router();
    }

    /**
     * @notice Gets the factory address from the router
     * @return The address of the factory contract
     * @dev Internal function to retrieve factory configuration
     */
    function _factory() internal view returns (address) {
        return ILPRouter(_router()).factory();
    }

    /**
     * @notice Gets the collateral token address from the router
     * @return The address of the collateral token
     * @dev Internal function to retrieve collateral token configuration
     */
    function _collateralToken() internal view returns (address) {
        return ILPRouter(_router()).collateralToken();
    }

    /**
     * @notice Gets the borrow token address from the router
     * @return The address of the borrow token
     * @dev Internal function to retrieve borrow token configuration
     */
    function _borrowToken() internal view returns (address) {
        return ILPRouter(_router()).borrowToken();
    }

    /**
     * @notice Gets the token data stream address from the factory
     * @return The address of the token data stream contract (price oracle)
     * @dev Internal function to retrieve oracle configuration
     */
    function _tokenDataStream() internal view returns (address) {
        return IFactory(_factory()).tokenDataStream();
    }

    /**
     * @notice Gets the wrapped native token address from the factory
     * @return The address of the wrapped native token (e.g., WETH, WMATIC)
     * @dev Internal function to retrieve wrapped native token configuration
     */
    function _wrappedNative() internal view returns (address) {
        return IFactory(_factory()).wrappedNative();
    }

    /**
     * @notice Gets the DEX router address from the factory
     * @return The address of the DEX router used for token swaps
     * @dev Internal function to retrieve DEX router configuration
     */
    function _dexRouter() internal view returns (address) {
        return IFactory(_factory()).dexRouter();
    }

    /**
     * @notice Gets the total borrow assets from the router
     * @return The total amount of borrow assets
     * @dev Internal function to retrieve total borrow assets in the lending pool
     */
    function _totalBorrowAssets() internal view returns (uint256) {
        return ILPRouter(_router()).totalBorrowAssets();
    }

    function _protocol() internal view returns (address) {
        return IFactory(_factory()).protocol();
    }

    /**
     * @notice Calculates the output amount for a token swap based on price feeds
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens
     * @return The calculated output amount in terms of the output token
     * @dev Uses price oracle to determine exchange rates
     * @dev Handles different token decimals automatically for accurate conversion
     * @dev Formula: amountOut = (amountIn * quotePrice * 10^tokenOutDecimal) / (basePrice * 10^tokenInDecimal)
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

    /**
     * @notice Internal function to transfer collateral to the user
     * @param amount The amount of collateral to withdraw
     * @param _user The address of the user to receive the collateral
     * @dev Handles both ERC20 tokens and native tokens
     * @dev For native tokens (address(1)), unwraps WETH and sends native tokens
     * @dev Sets _withdrawing flag to prevent re-wrapping during the receive function
     * @dev Reverts if native token transfer fails
     */
    function _withdrawCollateralTransfer(uint256 amount, address _user) internal {
        if (_collateralToken() == address(1)) {
            _withdrawing = true;
            IERC20(_wrappedNative()).approve(_wrappedNative(), amount);
            IWrappedNative(_wrappedNative()).withdraw(amount);
            (bool sent,) = _user.call{value: amount}("");
            if (!sent) revert TransferFailed();
            _withdrawing = false;
        } else {
            IERC20(_collateralToken()).safeTransfer(_user, amount);
        }
    }

    /**
     * @notice Calculates the amount of collateral needed to obtain a specific amount of borrow token
     * @param _collateral The address of the collateral token
     * @param _borrow The address of the borrow token
     * @param _amount The desired amount of borrow token
     * @return The amount of collateral needed
     * @dev Uses price oracles to determine the exchange rate between tokens
     * @dev Handles different token decimals for accurate conversion
     * @dev Formula: collateralNeeded = (_amount * borrowPrice * 10^collateralDecimal) / (collateralPrice * 10^borrowDecimal)
     */
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
    //                       DEX OPERATIONS
    // =============================================================

    /**
     * @notice Attempts a DEX swap with slippage protection
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens to swap
     * @param _amountOutMinimum The minimum amount of output tokens expected (slippage protection)
     * @return amountOut The actual amount of output tokens received
     * @dev Approves DEX router to spend input tokens
     * @dev Configures swap parameters including fee tier (0.1%), deadline, and slippage protection
     * @dev Reverts if output amount is less than minimum expected
     * @dev Uses Uniswap V3 style exactInputSingle swap
     */
    function _attemptDex(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMinimum)
        internal
        returns (uint256 amountOut)
    {
        IERC20(_tokenIn).approve(_dexRouter(), _amountIn);
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

        amountOut = IDexRouter(_dexRouter()).exactInputSingle(params);
        if (amountOut < _amountOutMinimum) revert InsufficientOutputAmount(amountOut, _amountOutMinimum);
        return amountOut;
    }

    /**
     * @notice Internal function to check and register tokens in the position's token list
     * @param _token The address of the token to check
     * @dev If token is not registered (tokenListsId == 0), increments counter and adds token to mappings
     * @dev Maintains bidirectional mapping between token IDs and addresses
     */
    function _checkTokenList(address _token) internal {
        if (tokenListsId[_token] == 0) {
            ++counter;
            tokenLists[counter] = _token;
            tokenListsId[_token] = counter;
        }
    }

    /**
     * @notice Internal function to enforce lending pool access control
     * @dev Reverts with OnlyForLendingPool if caller is not the lending pool
     */
    function _onlyLendingPool() internal view {
        if (msg.sender != lpAddress) revert OnlyForLendingPool();
    }

    /**
     * @notice Gets the current price of a token from the oracle
     * @param _token The address of the token
     * @return The current price of the token from the price feed
     * @dev Queries the token data stream (oracle) for the latest price
     * @dev Uses Chainlink-style latestRoundData interface
     */
    function _tokenPrice(address _token) internal view returns (uint256) {
        (, uint256 price,,,) = ITokenDataStream(_tokenDataStream()).latestRoundData(_token);
        return price;
    }

    /**
     * @notice Gets the number of decimals used by an ERC20 token
     * @param _token The token address to get decimals for
     * @return The number of decimals used by the ERC20 token
     * @dev Used to properly normalize token amounts for value calculations
     * @dev Special handling for wrapped native token (returns 18 decimals)
     * @dev For other tokens, queries the decimals() function via IERC20Metadata
     */
    function _tokenDecimals(address _token) internal view returns (uint256) {
        if (_token == _wrappedNative()) {
            return 18;
        }
        return IERC20Metadata(_token).decimals();
    }

    /**
     * @notice Reveals the actual token address (handles native token placeholder)
     * @param _token The token address (may be address(1) for native token)
     * @return The actual token address (wrapped native if input was address(1))
     * @dev Converts address(1) placeholder to the actual wrapped native token address
     * @dev Returns the input address unchanged if it's not the native token placeholder
     */
    function _revealToken(address _token) internal view returns (address) {
        if (_token == address(1)) {
            return _wrappedNative();
        }
        return _token;
    }

    // =============================================================
    //                    RECEIVE & FALLBACK
    // =============================================================

    /**
     * @notice Allows the contract to receive native tokens and automatically wraps them to Wrapped Native
     * @dev Required for native token collateral functionality
     * @dev Avoids infinite loop when Wrapped Native contract sends native tokens during withdrawal
     * @dev Only wraps if: position handles native tokens, not during withdrawal, and value > 0
     * @dev During withdrawal, accepts native tokens without wrapping to prevent re-wrapping loop
     * @dev Reverts if native tokens are sent to a position that doesn't handle them
     */
    receive() external payable {
        // Only wrap if this position handles native tokens and not during withdrawal
        if (msg.value > 0 && !_withdrawing && _collateralToken() == address(1)) {
            IWrappedNative(_wrappedNative()).deposit{value: msg.value}();
        } else if (msg.value > 0 && _withdrawing) {
            // During withdrawal, accept native tokens without wrapping
            return;
        } else if (msg.value > 0) {
            // Unexpected native token for non-native position
            revert("Position does not handle native tokens");
        }
    }

    /**
     * @notice Fallback function that rejects all calls to prevent accidental loss of funds
     * @dev Always reverts to prevent unexpected behavior
     */
    fallback() external payable {
        // Fallback should not accept native tokens to prevent accidental loss
        revert("Fallback not allowed");
    }
}
