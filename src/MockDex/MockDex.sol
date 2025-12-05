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

contract MockDex is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public factory;

    event ExactInputSingle(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, uint256 amountOutMinimum
    );

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

    function tokenCalculator(address _tokenIn, address _tokenOut, uint256 _amountIn) public view returns (uint256) {
        uint256 tokenInDecimal = IERC20Metadata(_tokenIn).decimals();
        uint256 tokenOutDecimal = IERC20Metadata(_tokenOut).decimals();

        uint256 quotePrice = _tokenPrice(_tokenIn);
        uint256 basePrice = _tokenPrice(_tokenOut);

        uint256 amountOut =
            (_amountIn * ((uint256(quotePrice) * (10 ** tokenOutDecimal)) / uint256(basePrice))) / 10 ** tokenInDecimal;
        return amountOut;
    }

    function _tokenDataStream() internal view returns (address) {
        return IFactory(factory).tokenDataStream();
    }

    function _oracleAddress(address _token) internal view returns (address) {
        return ITokenDataStream(_tokenDataStream()).tokenPriceFeed(_token);
    }

    function _tokenPrice(address _token) internal view returns (uint256) {
        (, uint256 price,,,) = ITokenDataStream(_tokenDataStream()).latestRoundData(_token);
        return price;
    }
}
