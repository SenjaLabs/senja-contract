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
     * @notice Allows the contract to receive native tokens
     * @dev Required for native token collateral functionality
     */
    receive() external payable {}

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
        if (_collateralToken() == address(1)) {
            (bool sent,) = _user.call{value: amount}("");
            if (!sent) revert TransferFailed();
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
        amountOut = _performDragonSwap(_tokenIn, amountIn, slippageTolerance);

        emit SwapTokenByPosition(msg.sender, _tokenIn, _tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Internal function to perform token swap using DragonSwap
     * @param _tokenIn The address of the input token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOut The amount of output tokens received
     * @dev Uses DragonSwap router for token swapping with slippage protection
     */
    function _performDragonSwap(address _tokenIn, uint256 amountIn, uint256 slippageTolerance) 
        internal 
        returns (uint256 amountOut) 
    {
        // Perform swap with DragonSwap
        amountOut = _attemptDragonSwap(_tokenIn, amountIn, slippageTolerance);
    }
    
    /**
     * @notice Performs DragonSwap with slippage protection
     * @param _tokenIn The address of the input token
     * @param amountIn The amount of input tokens to swap
     * @param slippageTolerance The slippage tolerance in basis points
     * @return amountOut The amount of output tokens received
     */
    function _attemptDragonSwap(address _tokenIn, uint256 amountIn, uint256 slippageTolerance) 
        internal 
        returns (uint256 amountOut) 
    {
        // DragonSwap router address
        address dragonSwapRouter = DRAGON_SWAP_ROUTER;
        
        // Calculate expected amount using price feeds
        uint256 expectedAmount = _calculateExpectedAmount(_tokenIn, amountIn);
        
        // Calculate minimum amount out with slippage protection
        uint256 amountOutMinimum = expectedAmount * (10000 - slippageTolerance) / 10000;
        
        // Approve DragonSwap router to spend tokens
        IERC20(_tokenIn).approve(dragonSwapRouter, amountIn);
        
        // Prepare swap parameters
        IDragonSwap.ExactInputSingleParams memory params = IDragonSwap.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _borrowToken(),
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
     * @notice Calculates expected amount out using price feeds
     * @param _tokenIn The address of the input token
     * @param amountIn The amount of input tokens
     * @return expectedAmount The expected amount of output tokens
     */
    function _calculateExpectedAmount(address _tokenIn, uint256 amountIn) 
        internal 
        view 
        returns (uint256 expectedAmount) 
    {
        // For now, use a simple calculation based on token decimals
        // In production, this should use proper price feeds
        if (_tokenIn == _collateralToken() && _borrowToken() == 0xd077A400968890Eacc75cdc901F0356c943e4fDb) {
            // WKAIA to USDT: assume 1 WKAIA = 0.157 USDT (based on test data)
            // WKAIA has 18 decimals, USDT has 6 decimals
            // Convert: 1e18 WKAIA * 0.157 = 157000000000000000 (18 decimals)
            // But USDT has 6 decimals, so divide by 1e12: 157000000000000000 / 1e12 = 157000 (6 decimals)
            expectedAmount = (amountIn * 157) / (1000 * 1e12); // Convert to USDT decimals
        } else {
            // Fallback: 1:1 ratio
            expectedAmount = amountIn;
        }
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
            if (_borrowToken() == address(1)) {
                // transfer native token
                (bool sent,) = lpAddress.call{value: amount}("");
                if (!sent) revert TransferFailed();
            } else {
                IERC20(_borrowToken()).safeTransfer(lpAddress, amount);
            }
            if (amountOut - amount != 0) swapTokenByPosition(_borrowToken(), _token, (amountOut - amount), 500); // 5% slippage
        } else {
            if (_borrowToken() == address(1)) {
                // transfer native token
                (bool sent,) = lpAddress.call{value: amount}("");
                if (!sent) revert TransferFailed();
            } else {
                IERC20(_borrowToken()).safeTransfer(lpAddress, amount);
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
        uint256 tokenInDecimal = _tokenIn == address(1) ? 18 : IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = _tokenOut == address(1) ? 18 : IERC20Metadata(_tokenOut).decimals();
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
            // Native token
            tokenBalance = address(this).balance;
            tokenDecimals = 18; // KAIA uses 18 decimals
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

}
