// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTAdapter.sol";
import {sUSDT} from "../../src/BridgeToken/sUSDT.sol";

contract SetElevated is Script, Helper {
    address public owner = vm.envAddress("PUBLIC_KEY");
    ElevatedMinterBurner public elevatedminterburner;

    function run() external {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        _setElevated();
        _setOperator();

        vm.stopBroadcast();
    }

    function _setElevated() internal {
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SUSDT), owner);
        elevatedminterburner.setOperator(address(BASE_OFT_SUSDT_ADAPTER), true);
        OFTUSDTadapter(BASE_OFT_SUSDT_ADAPTER).setElevatedMinterBurner(address(elevatedminterburner));
        console.log("address public BASE_USDTK_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
    }

    function _setOperator() internal {
        sUSDT(BASE_SUSDT).setOperator(BASE_SUSDT_ELEVATED_MINTER_BURNER, true);
        sUSDT(BASE_SUSDT).setOperator(BASE_OFT_SUSDT_ADAPTER, true);
    }
}

// RUN
// forge script SetElevated --broadcast -vvv
