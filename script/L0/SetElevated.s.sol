// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helper.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTAdapter.sol";
import {USDTk} from "../../src/BridgeToken/USDTk.sol";

contract SetElevated is Script, Helper {
    address public owner = vm.envAddress("PUBLIC_KEY");
    ElevatedMinterBurner public elevatedminterburner;

    function run() external {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // _setElevated();
        _setOperator();

        vm.stopBroadcast();
    }

    function _setElevated() internal {
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_USDTK), owner);
        elevatedminterburner.setOperator(address(BASE_OFT_USDTK_ADAPTER), true);
        OFTUSDTadapter(BASE_OFT_USDTK_ADAPTER).setElevatedMinterBurner(address(elevatedminterburner));
        console.log("address public BASE_USDTK_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
    }

    function _setOperator() internal {
        USDTk(BASE_USDTK).setOperator(BASE_USDTK_ELEVATED_MINTER_BURNER, true);
        USDTk(BASE_USDTK).setOperator(BASE_OFT_USDTK_ADAPTER, true);

    }
}

// RUN
// forge script SetElevated --broadcast -vvv
