// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IDragonSwap} from "./interfaces/IDragonSwap.sol";
import {IWKAIA} from "./interfaces/IWKAIA.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";

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
    /// @notice Error thrown when an invalid parameter is provided
    error InvalidParameter();
    /// @notice The collateral token address for this position

    address public owner;
    address public lpAddress;
    uint256 public counter;

    // DragonSwap router address on Kaia mainnet
    address public constant DRAGON_SWAP_ROUTER = 0xA324880f884036E3d21a09B90269E1aC57c7EC8a;

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
     * @notice Allows the contract to receive native tokens and automatically wraps them to WKAIA
     * @dev Required for native token collateral functionality
     * @dev Avoids infinite loop when WKAIA contract sends native tokens during withdrawal
     */
    receive() external payable {
        if (msg.value > 0 && !_withdrawing) {
            IWKAIA(_WKAIA()).deposit{value: msg.value}();
        }
    }

    fallback() external payable {
        // Auto-wrap incoming native KAIA to WKAIA, but not during withdrawal operations
        if (msg.value > 0 && !_withdrawing) {
            IWKAIA(_WKAIA()).deposit{value: msg.value}();
        }
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
     * @param unwrapToNative Whether to unwrap WKAIA to native KAIA for user
     * @dev Only the lending pool can call this function
     * @dev Transfers collateral tokens to the specified user
     */
    function withdrawCollateral(uint256 amount, address _user, bool unwrapToNative) public {
        // Allow withdrawals from lending pool, IsHealthy contract, or Liquidator contract
        address factory = _factory();
        address isHealthyContract = IFactory(factory).isHealthy();
        address liquidatorContract = IIsHealthy(isHealthyContract).liquidator();
        if (msg.sender != lpAddress && msg.sender != isHealthyContract && msg.sender != liquidatorContract) revert NotForWithdraw();
        if (_collateralToken() == address(1)) {
            if (unwrapToNative) {
                _withdrawing = true;
                IERC20(_WKAIA()).approve(_WKAIA(), amount);
                IWKAIA(_WKAIA()).withdraw(amount);
                (bool sent,) = _user.call{value: amount}("");
                if (!sent) revert TransferFailed();
                _withdrawing = false;
            } else {
                IERC20(_WKAIA()).safeTransfer(_user, amount);
            }
        } else {
            IERC20(_collateralToken()).safeTransfer(_user, amount);
        }
        emit WithdrawCollateral(_user, amount);
    }

    /**
     * @notice Swaps tokens within the position using DragonSwap
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points (e.g., 500 = 5%)
     * @return amountOut The amount of output tokens received
     * @dev Only the position owner can call this function
     * @dev Uses DragonSwap router for token swapping with slippage protection
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
        if (msg.sender != owner) revert NotForSwap();
        if (slippageTolerance > 10000) revert InvalidParameter(); // Max 100% slippage

        // Perform DragonSwap with slippage protection
        amountOut = _performDragonSwap(_tokenIn, _tokenOut, amountIn, slippageTolerance);

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
        if (_token != _borrowToken()) {
            uint256 amountOut = swapTokenByPosition(_token, _borrowToken(), balance, 500); // 5% slippage
            IERC20(_token).approve(lpAddress, amount);
            IERC20(_borrowToken() == address(1) ? _WKAIA() : _borrowToken()).safeTransfer(lpAddress, amount);
            if (amountOut - amount != 0) swapTokenByPosition(_borrowToken(), _token, (amountOut - amount), 500); // 5% slippage
        } else {
            IERC20(_token).approve(lpAddress, amount);
            IERC20(_borrowToken() == address(1) ? _WKAIA() : _borrowToken()).safeTransfer(lpAddress, amount);
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
        uint256 tokenInDecimal = _tokenIn == _WKAIA() ? 18 : IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = _tokenOut == _WKAIA() ? 18 : IERC20Metadata(_tokenOut).decimals();
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
            // WKAIA token (wrapped KAIA)
            tokenBalance = IERC20(_WKAIA()).balanceOf(address(this));
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

    function _WKAIA() internal view returns (address) {
        return IFactory(_factory()).WKAIA();
    }

    /**
     * @notice Internal function to perform token swap using DragonSwap
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOut The amount of output tokens received
     * @dev Uses DragonSwap router for token swapping with slippage protection
     */
    function _performDragonSwap(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        internal
        returns (uint256 amountOut)
    {
        // Perform swap with DragonSwap
        amountOut = _attemptDragonSwap(_tokenIn, _tokenOut, amountIn, slippageTolerance);
    }

    /**
     * @notice Performs DragonSwap with slippage protection
     * @param _tokenIn The address of the input token
     * @param _tokenOut The address of the output token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOut The amount of output tokens received
     */
    function _attemptDragonSwap(address _tokenIn, address _tokenOut, uint256 amountIn, uint256 slippageTolerance)
        internal
        returns (uint256 amountOut)
    {
        // DragonSwap router address
        address dragonSwapRouter = DRAGON_SWAP_ROUTER;

        // Calculate expected amount using price feeds
        uint256 expectedAmount = _calculateExpectedAmount(_tokenIn, _tokenOut, amountIn);

        // Calculate minimum amount out with slippage protection
        uint256 amountOutMinimum = expectedAmount * (10000 - slippageTolerance) / 10000;

        // Approve DragonSwap router to spend tokens
        IERC20(_tokenIn).approve(dragonSwapRouter, amountIn);

        // Prepare swap parameters
        IDragonSwap.ExactInputSingleParams memory params = IDragonSwap.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut == address(1) ? _WKAIA() : _tokenOut,
            fee: 1000, // 0.1% fee tier
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes deadline
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum, // Slippage protection
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Perform the swap
        amountOut = IDragonSwap(dragonSwapRouter).exactInputSingle(params);
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
        if (_token == address(1) || _token == _WKAIA()) {
            decimals = 18;
        } else {
            decimals = IERC20Metadata(_token).decimals();
        }
    }
}
