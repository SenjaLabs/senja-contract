// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {IWrappedNative} from "../../src/interfaces/IWrappedNative.sol";
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
        IWrappedNative(KAIA_WKAIA).deposit{value: 1e18}();
        console.log("balance after deposit: ", vm.envAddress("PUBLIC_KEY"));
        console.log("balance token after deposit: ", IERC20(KAIA_WKAIA).balanceOf(vm.envAddress("PUBLIC_KEY")));
        vm.stopBroadcast();
    }
}

// RUN
// forge script ConvertToWrappedToken --broadcast -vvv
