// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {USDTk} from "../../src/BridgeToken/USDTk.sol";
import {WKAIAk} from "../../src/BridgeToken/WKAIAk.sol";
import {WBTCk} from "../../src/BridgeToken/WBTCk.sol";
import {WETHk} from "../../src/BridgeToken/WETHk.sol";

contract GrantRole is Script, Helper {
    address USDTK;
    address WKAIAK;
    address WBTCK;
    address WETHK;
    address USDTK_ELEVATED_MINTER_BURNER;
    address WKAIAK_ELEVATED_MINTER_BURNER;
    address WBTCK_ELEVATED_MINTER_BURNER;
    address WETHK_ELEVATED_MINTER_BURNER;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        USDTk(USDTK).setOperator(USDTK_ELEVATED_MINTER_BURNER, true);
        console.log("USDTk operator set");
        WKAIAk(WKAIAK).setOperator(WKAIAK_ELEVATED_MINTER_BURNER, true);
        console.log("WKAIAk operator set");
        WBTCk(WBTCK).setOperator(WBTCK_ELEVATED_MINTER_BURNER, true);
        console.log("WBTCk operator set");
        WETHk(WETHK).setOperator(WETHK_ELEVATED_MINTER_BURNER, true);
        console.log("WETHk operator set");
        vm.stopBroadcast();
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            USDTK = BASE_USDTK;
            WKAIAK = BASE_WKAIAK;
            WBTCK = BASE_WBTCK;
            WETHK = BASE_WETHK;
            USDTK_ELEVATED_MINTER_BURNER = BASE_USDTK_ELEVATED_MINTER_BURNER;
            WKAIAK_ELEVATED_MINTER_BURNER = BASE_WKAIAK_ELEVATED_MINTER_BURNER;
            WBTCK_ELEVATED_MINTER_BURNER = BASE_WBTCK_ELEVATED_MINTER_BURNER;
            WETHK_ELEVATED_MINTER_BURNER = BASE_WETHK_ELEVATED_MINTER_BURNER;
        }
    }
}

// RUN
// forge script GrantRole --broadcast -vvv
