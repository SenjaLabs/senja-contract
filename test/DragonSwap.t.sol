// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface DragonSwap {
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

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
contract DragonSwapTest is Test {
    address public owner = makeAddr("owner");

    address public swapRouter = 0x5EA3e22C41B08DD7DC7217549939d987ED410354;

    address public USDT = 0xd077A400968890Eacc75cdc901F0356c943e4fDb;
    address public WKAIA = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        deal(USDT, owner, 100_000e6);
        vm.deal(owner, 100 ether);
    }

    // RUN
    // forge test --match-test test_swap -vvv
    function test_swap() public {
        vm.startPrank(owner);
        IERC20(USDT).approve(swapRouter, 1_000e6);
        DragonSwap(swapRouter).exactInputSingle(
            DragonSwap.ExactInputSingleParams({
                tokenIn: USDT,
                tokenOut: WKAIA,
                fee: 1000,
                recipient: owner,
                deadline: block.timestamp + 1000,
                amountIn: 1_000e6,
                amountOutMinimum: 1e6,
                sqrtPriceLimitX96: 0
            })
        );
        console.log("balance of WKAIA: ", IERC20(WKAIA).balanceOf(owner));
        console.log("balance of USDT: ", IERC20(USDT).balanceOf(owner));
        vm.stopPrank();
    }
}
