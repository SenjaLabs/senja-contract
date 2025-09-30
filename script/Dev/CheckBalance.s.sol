// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LendingPool} from "../../src/LendingPool.sol";

contract CheckBalance is Script, Helper {
    function run() external {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // console.log(
        //     "balance of KAIA_OFT_MOCK_USDT_ADAPTER", IERC20(KAIA_MOCK_USDT).balanceOf(KAIA_OFT_MOCK_USDT_ADAPTER)
        // );
        LendingPool(payable(address(0x483f98e04C6AeCB40563B443Aa4e8C8d7662cc0F))).withdrawLiquidity(1e6);
        vm.stopBroadcast();
    }
}

// RUN
// forge script CheckBalance --broadcast -vvv
