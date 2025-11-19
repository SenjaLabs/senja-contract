// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {Oracle} from "../../src/Oracle.sol";

contract DeployOracleAdapter is Script, Helper {
    Oracle public oracle;

    address native_usdt_adapter;
    address usdt_usd_adapter;
    address eth_usdt_adapter;
    address btc_usdt_adapter;

    function run() public {
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.createSelectFork(vm.rpcUrl("kaia_testnet"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        oracle = new Oracle(native_usdt);
        native_usdt_adapter = address(oracle);
        oracle = new Oracle(usdt_usd);
        usdt_usd_adapter = address(oracle);
        oracle = new Oracle(eth_usdt);
        eth_usdt_adapter = address(oracle);
        oracle = new Oracle(btc_usdt);
        btc_usdt_adapter = address(oracle);

        console.log("address public %s_usdt_usd_adapter = %s;", _getChainName(), usdt_usd_adapter);
        console.log("address public %s_native_usdt_adapter = %s;", _getChainName(), native_usdt_adapter);
        console.log("address public %s_eth_usdt_adapter = %s;", _getChainName(), eth_usdt_adapter);
        console.log("address public %s_btc_usdt_adapter = %s;", _getChainName(), btc_usdt_adapter);

        vm.stopBroadcast();
    }

    function _getChainName() internal view returns (string memory) {
        if (block.chainid == 8217) return "KAIA";
        if (block.chainid == 8453) return "BASE";
        if (block.chainid == 1284) return "GLMR";
        if (block.chainid == 1001) return "KAIA_TESTNET";
        revert("UNKNOWN CHAIN");
    }
}
// RUN
// forge script DeployOracleAdapter --broadcast -vvv --verify --verifier oklink --verifier-url https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/kaia
// forge script DeployOracleAdapter --broadcast -vvv --verify
// forge script DeployOracleAdapter --broadcast -vvv
// forge script DeployOracleAdapter -vvv
