// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
import {Oracle} from "../../src/Oracle.sol";

contract DeployOracleAdapter is Script, Helper {
    Oracle public oracle;
    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        oracle = new Oracle(usdt_usd);
        console.log("address public usdt_usd_adapter =", address(oracle), ";");
        oracle = new Oracle(kaia_usdt);
        console.log("address public kaia_usdt_adapter =", address(oracle), ";");
        oracle = new Oracle(eth_usdt);
        console.log("address public eth_usdt_adapter =", address(oracle), ";");
        oracle = new Oracle(btc_usdt);
        console.log("address public btc_usdt_adapter =", address(oracle), ";");
        vm.stopBroadcast();
    }
}
// RUN
// forge script DeployOracleAdapter --broadcast -vvv
