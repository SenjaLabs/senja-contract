// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {Oracle} from "../../src/Oracle.sol";

contract DeployOracleAdapter is Script, Helper {
    Oracle public oracle;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        oracle = new Oracle(usdt_usd);
        console.log("address public %s_usdt_usd_adapter = %s;", _getChainName(), address(oracle));
        oracle = new Oracle(native_usdt);
        console.log("address public %s_native_usdt_adapter = %s;", _getChainName(), address(oracle));
        oracle = new Oracle(eth_usdt);
        console.log("address public %s_eth_usdt_adapter = %s;", _getChainName(), address(oracle));
        oracle = new Oracle(btc_usdt);
        console.log("address public %s_btc_usdt_adapter = %s;", _getChainName(), address(oracle));
        vm.stopBroadcast();
    }

    function _getChainName() internal view returns (string memory) {
        if (block.chainid == 8217) return "KAIA";
        if (block.chainid == 8453) return "BASE";
        if (block.chainid == 1284) return "GLMR";
        return "UNKNOWN";
    }
}
// RUN
// forge script DeployOracleAdapter --broadcast -vvv
