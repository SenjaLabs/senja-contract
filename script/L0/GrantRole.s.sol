// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helper.sol";
import {USDTk} from "../../src/BridgeToken/USDTk.sol";
import {WKAIAk} from "../../src/BridgeToken/WKAIAk.sol";
import {WBTCk} from "../../src/BridgeToken/WBTCk.sol";
import {WETHk} from "../../src/BridgeToken/WETHk.sol";

contract GrantRole is Script, Helper {
    function run() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        USDTk(BASE_USDTK).setOperator(BASE_USDTK_ELEVATED_MINTER_BURNER, true);
        console.log("USDTk operator set");
        WKAIAk(BASE_WKAIAK).setOperator(BASE_WKAIAK_ELEVATED_MINTER_BURNER, true);
        console.log("WKAIAk operator set");
        WBTCk(BASE_WBTCK).setOperator(BASE_WBTCK_ELEVATED_MINTER_BURNER, true);
        console.log("WBTCk operator set");
        WETHk(BASE_WETHK).setOperator(BASE_WETHK_ELEVATED_MINTER_BURNER, true);
        console.log("WETHk operator set");
        vm.stopBroadcast();
    }
}

// RUN
// forge script GrantRole --broadcast -vvv