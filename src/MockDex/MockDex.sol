// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IMintableBurnable} from "../interfaces/IMintableBurnable.sol";
import {IFactory} from "../interfaces/IFactory.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {ITokenDataStream} from "../interfaces/ITokenDataStream.sol";

/**
 * @title MockDex
 * @notice Mock decentralized exchange for testing token swaps with oracle-based pricing
 * @dev Simulates DEX functionality by burning input tokens and minting output tokens based on oracle prices
 */
contract MockDex is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Address of the factory contract
    address public factory;

    /// @notice Emitted when a token swap is executed
    /// @param tokenIn Address of the input token
    /// @param tokenOut Address of the output token
    /// @param amountIn Amount of input tokens swapped
    /// @param amountOut Amount of output tokens received
    /// @param amountOutMinimum Minimum amount of output tokens expected
    event ExactInputSingle(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, uint256 amountOutMinimum
    );

    /**
     * @notice Constructs the MockDex contract
     * @param _factory Address of the factory contract
     */
    constructor(address _factory) Ownable(msg.sender) {
        factory = _factory;
    }

    /**
     * @notice Sets the factory contract address
     * @param _factory New factory contract address
     * @dev Only callable by contract owner
     */
    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    /**
     * @notice Parameters for executing an exact input swap
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param fee Fee tier for the swap (not used in mock implementation)
     * @param recipient Address to receive the output tokens
     * @param deadline Transaction deadline timestamp
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMinimum Minimum amount of output tokens to receive
     * @param sqrtPriceLimitX96 Price limit (not used in mock implementation)
     */
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Executes a token swap with exact input amount
     * @param params Swap parameters containing token addresses, amounts, and constraints
     * @return amountOut Amount of output tokens received
     * @dev Burns input tokens and mints output tokens based on oracle price ratio
     */
    function exactInputSingle(ExactInputSingleParams memory params)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);

        amountOut = tokenCalculator(params.tokenIn, params.tokenOut, params.amountIn);

        IMintableBurnable(params.tokenIn).burn(address(this), params.amountIn);
        IMintableBurnable(params.tokenOut).mint(msg.sender, amountOut);

        emit ExactInputSingle(params.tokenIn, params.tokenOut, params.amountIn, amountOut, params.amountOutMinimum);
    }

    /**
     * @notice Calculates the output amount for a token swap based on oracle prices
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _amountIn Amount of input tokens
     * @return Amount of output tokens calculated from price ratio
     * @dev Uses oracle prices and adjusts for token decimals
     */
    function tokenCalculator(address _tokenIn, address _tokenOut, uint256 _amountIn) public view returns (uint256) {
        uint256 tokenInDecimal = IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = IERC20Metadata(_tokenOut).decimals();

        uint256 quotePrice = _tokenPrice(_tokenIn);
        uint256 basePrice = _tokenPrice(_tokenOut);

        uint256 amountOut =
            (_amountIn * ((uint256(quotePrice) * (10 ** tokenOutDecimal)) / uint256(basePrice))) / 10 ** tokenInDecimal;
        return amountOut;
    }

    /**
     * @notice Internal function to get the token data stream contract address
     * @return Address of the token data stream contract
     */
    function _tokenDataStream() internal view returns (address) {
        return IFactory(factory).tokenDataStream();
    }

    /**
     * @notice Internal function to get the oracle address for a specific token
     * @param _token Address of the token
     * @return Address of the oracle for the given token
     */
    function _oracleAddress(address _token) internal view returns (address) {
        return ITokenDataStream(_tokenDataStream()).tokenPriceFeed(_token);
    }

    /**
     * @notice Internal function to get the current price of a token from the oracle
     * @param _token Address of the token
     * @return Current price of the token from the oracle
     */
    function _tokenPrice(address _token) internal view returns (uint256) {
        (, uint256 price,,,) = ITokenDataStream(_tokenDataStream()).latestRoundData(_token);
        return price;
    }
}
