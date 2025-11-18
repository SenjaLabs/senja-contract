// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFactory} from "../interfaces/IFactory.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMintableBurnable} from "../interfaces/IMintableBurnable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MockDex is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public factory;

    event ExactInputSingle(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, uint256 amountOutMinimum);

    constructor(address _factory) Ownable(msg.sender) {
        factory = _factory;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

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

    function exactInputSingle(ExactInputSingleParams memory params) external payable nonReentrant returns (uint256 amountOut) {
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);

        address _tokenInPrice = IFactory(factory).tokenDataStream(params.tokenIn);
        address _tokenOutPrice = IFactory(factory).tokenDataStream(params.tokenOut);

        amountOut = tokenCalculator(params.tokenIn, params.tokenOut, params.amountIn, _tokenInPrice, _tokenOutPrice);

        IMintableBurnable(params.tokenIn).burn(address(this), params.amountIn);
        IMintableBurnable(params.tokenOut).mint(msg.sender, amountOut);

        emit ExactInputSingle(params.tokenIn, params.tokenOut, params.amountIn, amountOut, params.amountOutMinimum);
    }

    function tokenCalculator(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _tokenInPrice,
        address _tokenOutPrice
    ) public view returns (uint256) {
        uint256 tokenInDecimal = IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = IERC20Metadata(_tokenOut).decimals();

        (, uint256 quotePrice,,,) = IOracle(_tokenInPrice).latestRoundData();
        (, uint256 basePrice,,,) = IOracle(_tokenOutPrice).latestRoundData();

        uint256 amountOut = (_amountIn * ((uint256(quotePrice) * (10 ** tokenOutDecimal)) / uint256(basePrice))) / 10 ** tokenInDecimal;
        return amountOut;
    }
}
