// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {sUSDT} from "../../src/BridgeToken/sUSDT.sol";
import {sWKAIA} from "../../src/BridgeToken/sWKAIA.sol";
import {sWBTC} from "../../src/BridgeToken/sWBTC.sol";
import {sWETH} from "../../src/BridgeToken/sWETH.sol";

contract GrantRole is Script, Helper {
    address SUSDT;
    address SWKAIA;
    address SWBTC;
    address SWETH;
    address SUSDT_ELEVATED_MINTER_BURNER;
    address SWKAIA_ELEVATED_MINTER_BURNER;
    address SWBTC_ELEVATED_MINTER_BURNER;
    address SWETH_ELEVATED_MINTER_BURNER;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        sUSDT(SUSDT).setOperator(SUSDT_ELEVATED_MINTER_BURNER, true);
        console.log("sUSDT operator set");
        sWKAIA(SWKAIA).setOperator(SWKAIA_ELEVATED_MINTER_BURNER, true);
        console.log("sWKAIA operator set");
        sWBTC(SWBTC).setOperator(SWBTC_ELEVATED_MINTER_BURNER, true);
        console.log("WBTCk operator set");
        sWETH(SWETH).setOperator(SWETH_ELEVATED_MINTER_BURNER, true);
        console.log("WETHk operator set");
        vm.stopBroadcast();
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            SUSDT = BASE_SUSDT;
            SWKAIA = BASE_SWKAIA;
            SWBTC = BASE_SWBTC;
            SWETH = BASE_SWETH;
            SUSDT_ELEVATED_MINTER_BURNER = BASE_SUSDT_ELEVATED_MINTER_BURNER;
            SWKAIA_ELEVATED_MINTER_BURNER = BASE_SWKAIA_ELEVATED_MINTER_BURNER;
            SWBTC_ELEVATED_MINTER_BURNER = BASE_SWBTC_ELEVATED_MINTER_BURNER;
            SWETH_ELEVATED_MINTER_BURNER = BASE_SWETH_ELEVATED_MINTER_BURNER;
        }
    }
}

// RUN
// forge script GrantRole --broadcast -vvv
