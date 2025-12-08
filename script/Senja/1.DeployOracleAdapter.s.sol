// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {Oracle} from "../../src/Oracle.sol";

contract DeployOracleAdapter is Script, Helper {
    Oracle public oracle;

    address nativeUsdtAdapter;
    address usdtUsdAdapter;
    address ethUsdtAdapter;
    address btcUsdtAdapter;

    function run() public {
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.createSelectFork(vm.rpcUrl("kaia_testnet"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        oracle = new Oracle(NATIVE_USDT);
        nativeUsdtAdapter = address(oracle);
        oracle = new Oracle(USDT_USD);
        usdtUsdAdapter = address(oracle);
        oracle = new Oracle(ETH_USDT);
        ethUsdtAdapter = address(oracle);
        oracle = new Oracle(BTC_USDT);
        btcUsdtAdapter = address(oracle);

        console.log("address public %s_usdt_usd_adapter = %s;", _getChainName(), usdtUsdAdapter);
        console.log("address public %s_native_usdt_adapter = %s;", _getChainName(), nativeUsdtAdapter);
        console.log("address public %s_eth_usdt_adapter = %s;", _getChainName(), ethUsdtAdapter);
        console.log("address public %s_btc_usdt_adapter = %s;", _getChainName(), btcUsdtAdapter);

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
