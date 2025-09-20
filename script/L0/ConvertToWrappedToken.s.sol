// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helper.sol";
import {IWKAIA} from "../../src/interfaces/IWKAIA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConvertToWrappedToken is Script, Helper {
    function run() public {
        deployKAIA();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        console.log("balance before deposit: ", vm.envAddress("PUBLIC_KEY"));
        console.log("balance token before deposit: ", IERC20(KAIA_WKAIA).balanceOf(vm.envAddress("PUBLIC_KEY")));
        IWKAIA(KAIA_WKAIA).deposit{value: 1e18}();
        console.log("balance after deposit: ", vm.envAddress("PUBLIC_KEY"));
        console.log("balance token after deposit: ", IERC20(KAIA_WKAIA).balanceOf(vm.envAddress("PUBLIC_KEY")));
        vm.stopBroadcast();
    }
}

// RUN
// forge script ConvertToWrappedToken --broadcast -vvv
