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

    /**
     * @notice Modifier to check and register tokens in the position's token list
     * @param _token The address of the token to check
     * @dev Automatically adds new tokens to the position's token tracking system
     */
    modifier checkTokenList(address _token) {
        _checkTokenList(_token);
        _;
    }

    /**
     * @notice Withdraws collateral from the position
     * @param amount The amount of collateral to withdraw
     * @param _user The address of the user to receive the collateral
     * @param unwrapToNative Whether to unwrap Wrapped Native to native for user
     * @dev Only authorized contracts can call this function
     * @dev Transfers collateral tokens to the specified user
     */
    function withdrawCollateral(uint256 amount, address _user, bool unwrapToNative) public {
        _onlyAuthorizedWithdrawal();
        if (amount == 0) revert ZeroAmount();
        if (_collateralToken() == address(1)) {
            if (unwrapToNative) {
                _withdrawing = true;
                IERC20(_WRAPPED_NATIVE()).approve(_WRAPPED_NATIVE(), amount);
                IWrappedNative(_WRAPPED_NATIVE()).withdraw(amount);
                (bool sent,) = _user.call{value: amount}("");
                if (!sent) revert TransferFailed();
                _withdrawing = false;
            } else {
                IERC20(_WRAPPED_NATIVE()).safeTransfer(_user, amount);
            }
        } else {
            IERC20(_collateralToken()).safeTransfer(_user, amount);
        }
        emit WithdrawCollateral(_user, amount);
    }

    /**
     * @notice Swaps tokens within the position using DEX
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points (e.g., 500 = 5%)
     * @return amountOut The amount of output tokens received
     * @dev Only the position owner can call this function
     * @dev Uses DEX router for token swapping with slippage protection
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        public
        checkTokenList(_tokenIn)
        checkTokenList(_tokenOut)
        returns (uint256 amountOut)
    {
        uint256 balances = IERC20(_tokenIn).balanceOf(address(this));
        if (amountIn == 0) revert ZeroAmount();
        if (balances < amountIn) revert InsufficientBalance();
        if (_tokenIn == _tokenOut) revert InvalidParameter();
        if (
            IFactory(_factory()).tokenDataStream(_tokenIn) == address(0)
                || IFactory(_factory()).tokenDataStream(_tokenOut) == address(0)
        ) revert OracleOnTokenNotSet();
        if (msg.sender != owner && msg.sender != lpAddress) revert NotForSwap();
        if (slippageTolerance > 10000) revert InvalidParameter(); // Max 100% slippage

        amountOut = _performDex(_tokenIn, _tokenOut, amountIn, slippageTolerance);

        emit SwapTokenByPosition(msg.sender, _tokenIn, _tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Repays a loan using a selected token
     * @param amount The amount to repay
     * @param _token The address of the token to use for repayment
     * @param slippageTolerance Slippage tolerance in basis points (e.g., 500 = 5%)
     * @dev Only authorized contracts can call this function
     * @dev If the selected token is not the borrow asset, it will be swapped first
     * @dev Any excess tokens after repayment are swapped back to the original token
     */
    function repayWithSelectedToken(uint256 amount, address _token, uint256 slippageTolerance) public payable {
        _onlyAuthorizedWithdrawal();

        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        if (_token != _borrowToken()) {
            uint256 amountOut = swapTokenByPosition(_token, _borrowToken(), balance, slippageTolerance);
            if (amountOut < amount) revert InsufficientBalance();

            IERC20(_token).approve(lpAddress, amount);
            IERC20(_borrowToken() == address(1) ? _WRAPPED_NATIVE() : _borrowToken()).safeTransfer(lpAddress, amount);

            uint256 remaining = amountOut - amount;
            if (remaining > 0) {
                swapTokenByPosition(_borrowToken(), _token, remaining, slippageTolerance);
            }
        } else {
            IERC20(_token).approve(lpAddress, amount);
            IERC20(_borrowToken() == address(1) ? _WRAPPED_NATIVE() : _borrowToken()).safeTransfer(lpAddress, amount);
        }
    }

    /**
     * @notice Calculates the output amount for a token swap based on price feeds
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param _amountIn The amount of input tokens
     * @param _tokenInPrice The address of the input token's price feed
     * @param _tokenOutPrice The address of the output token's price feed
     * @return Calculated output amount
     * @dev Uses PriceFeedIOracle price feeds to determine exchange rates
     * @dev Handles different token decimals automatically
     */
    function tokenCalculator(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _tokenInPrice,
        address _tokenOutPrice
    ) public view returns (uint256) {
        uint256 tokenInDecimal = _tokenIn == _WRAPPED_NATIVE() ? 18 : IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = _tokenOut == _WRAPPED_NATIVE() ? 18 : IERC20Metadata(_tokenOut).decimals();
        (, uint256 quotePrice,,,) = IOracle(_tokenInPrice).latestRoundData();
        (, uint256 basePrice,,,) = IOracle(_tokenOutPrice).latestRoundData();

        uint256 amountOut =
            (_amountIn * ((uint256(quotePrice) * (10 ** tokenOutDecimal)) / uint256(basePrice))) / 10 ** tokenInDecimal;

        return amountOut;
    }

    /**
     * @notice Calculates the USD value of a token balance in the position
     * @param token The address of the token to calculate value for
     * @return The USD value of the token balance (in 18 decimals)
     * @dev Uses PriceFeedIOracle price feeds to get current token prices
     * @dev Returns value normalized to 18 decimals for consistency
     */
    function tokenValue(address token) public view returns (uint256) {
        uint256 tokenBalance;
        uint256 tokenDecimals;

        if (token == address(1)) {
            // Wrapped Native token
            tokenBalance = IERC20(_WRAPPED_NATIVE()).balanceOf(address(this));
            tokenDecimals = 18;
        } else {
            // ERC20 token
            tokenBalance = IERC20(token).balanceOf(address(this));
            tokenDecimals = IERC20Metadata(token).decimals();
        }

        (, uint256 tokenPrice,,,) = IOracle(_tokenDataStream(token)).latestRoundData();
        uint256 tokenAdjustedPrice = uint256(tokenPrice) * 1e18 / (10 ** _oracleDecimal(token)); // token standarize to 18 decimal, and divide by price decimals
        uint256 value = (tokenBalance * tokenAdjustedPrice) / (10 ** tokenDecimals);

        return value;
    }

    function _checkTokenList(address _token) internal {
        if (tokenListsId[_token] == 0) {
            ++counter;
            tokenLists[counter] = _token;
            tokenListsId[_token] = counter;
        }
    }

    /**
     * @notice Checks if the caller is authorized to perform withdrawal operations
     * @dev Only lending pool, IsHealthy contract, or Liquidator contract can call
     */
    function _onlyAuthorizedWithdrawal() internal view {
        address factory = _factory();
        address isHealthyContract = IFactory(factory).isHealthy();
        address liquidatorContract = IIsHealthy(isHealthyContract).liquidator();

        if (msg.sender != lpAddress && msg.sender != isHealthyContract && msg.sender != liquidatorContract) {
            revert NotForWithdraw();
        }
    }

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

    function _oracleDecimal(address _token) internal view returns (uint256) {
        return IOracle(_tokenDataStream(_token)).decimals();
    }

    function _tokenDataStream(address _token) internal view returns (address) {
        return IFactory(_factory()).tokenDataStream(_token);
    }

    function _WRAPPED_NATIVE() internal view returns (address) {
        return IFactory(_factory()).WRAPPED_NATIVE();
    }

    /**
     * @notice Internal function to perform token swap using DEX
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOut The amount of output tokens received
     * @dev Uses DEX router for token swapping with slippage protection
     */
    function _performDex(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        internal
        returns (uint256 amountOut)
    {
        // Perform swap with DEX
        amountOut = _attemptDex(_tokenIn, _tokenOut, amountIn, slippageTolerance);
    }

    /**
     * @notice Performs DEX with slippage protection
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOut The amount of output tokens received
     */
    function _attemptDex(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        internal
        returns (uint256 amountOut)
    {
        // Calculate expected amount using price feeds
        uint256 expectedAmount = _calculateExpectedAmount(_tokenIn, _tokenOut, amountIn);

        // Calculate minimum amount out with slippage protection
        uint256 amountOutMinimum = expectedAmount * (10000 - slippageTolerance) / 10000;

        // Approve DEX router to spend tokens
        IERC20(_tokenIn).approve(_DEX_ROUTER(), amountIn);

        // Prepare swap parameters
        IDexRouter.ExactInputSingleParams memory params = IDexRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut == address(1) ? _WRAPPED_NATIVE() : _tokenOut,
            fee: 1000, // 0.1% fee tier
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes deadline
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum, // Slippage protection
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Perform the swap
        amountOut = IDexRouter(_DEX_ROUTER()).exactInputSingle(params);
    }

    /**
     * @notice Calculates expected amount out using dynamic price feeds
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @return expectedAmount The expected amount of output tokens
     * @dev Uses the existing price oracle infrastructure to calculate dynamic exchange rates
     * @dev Handles different token decimals automatically
     * @dev Falls back to 1:1 ratio if price feeds are not available
     */
    function _calculateExpectedAmount(address _tokenIn, address _tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 expectedAmount)
    {
        // Handle case where we're swapping to the same token
        if (_tokenIn == _tokenOut) {
            return amountIn;
        }

        try this._calculateExpectedAmountWithPriceFeeds(_tokenIn, _tokenOut, amountIn) returns (uint256 amount) {
            expectedAmount = amount;
        } catch {
            uint256 tokenInDecimals = _getTokenDecimals(_tokenIn);
            uint256 tokenOutDecimals = _getTokenDecimals(_tokenOut);

            if (tokenInDecimals > tokenOutDecimals) {
                expectedAmount = amountIn / (10 ** (tokenInDecimals - tokenOutDecimals));
            } else if (tokenOutDecimals > tokenInDecimals) {
                expectedAmount = amountIn * (10 ** (tokenOutDecimals - tokenInDecimals));
            } else {
                expectedAmount = amountIn;
            }
        }
    }

    /**
     * @notice Internal function to calculate expected amount using price feeds
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @return expectedAmount The expected amount of output tokens
     * @dev This function will revert if price feeds are not available
     */
    function _calculateExpectedAmountWithPriceFeeds(address _tokenIn, address _tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 expectedAmount)
    {
        // Only allow calls from this contract
        require(msg.sender == address(this), "Unauthorized");

        // Get token decimals
        uint256 tokenInDecimals = _getTokenDecimals(_tokenIn);
        uint256 tokenOutDecimals = _getTokenDecimals(_tokenOut);

        // Get price feed addresses
        address tokenInPriceFeed = _tokenDataStream(_tokenIn);
        address tokenOutPriceFeed = _tokenDataStream(_tokenOut);

        // Get current prices from oracles
        (, uint256 tokenInPrice,,,) = IOracle(tokenInPriceFeed).latestRoundData();
        (, uint256 tokenOutPrice,,,) = IOracle(tokenOutPriceFeed).latestRoundData();

        // Get oracle decimals for price normalization
        uint256 tokenInPriceDecimals = _oracleDecimal(_tokenIn);
        uint256 tokenOutPriceDecimals = _oracleDecimal(_tokenOut);

        // Normalize prices to 18 decimals for calculation
        uint256 normalizedTokenInPrice = tokenInPrice * 1e18 / (10 ** tokenInPriceDecimals);
        uint256 normalizedTokenOutPrice = tokenOutPrice * 1e18 / (10 ** tokenOutPriceDecimals);

        // Calculate expected amount out
        // Formula: (amountIn * tokenInPrice / tokenOutPrice) adjusted for decimals
        expectedAmount = (amountIn * normalizedTokenInPrice * (10 ** tokenOutDecimals))
            / (normalizedTokenOutPrice * (10 ** tokenInDecimals));
    }

    /**
     * @notice Helper function to get token decimals
     * @param _token The address of the token
     * @return decimals The number of decimals for the token
     */
    function _getTokenDecimals(address _token) internal view returns (uint256 decimals) {
        if (_token == address(1) || _token == _WRAPPED_NATIVE()) {
            decimals = 18;
        } else {
            decimals = IERC20Metadata(_token).decimals();
        }
    }

    function _DEX_ROUTER() internal view returns (address) {
        return IFactory(_factory()).DEX_ROUTER();
    }
}
