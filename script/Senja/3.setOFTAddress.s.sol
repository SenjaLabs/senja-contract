// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
import {IFactory} from "../../src/interfaces/IFactory.sol";

contract SetOFTAddress is Script, Helper {
    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        console.log("oftaddress of kaia_usdt before set: ", IFactory(address(KAIA_lendingPoolFactoryProxy)).oftAddress(KAIA_USDT));
        IFactory(address(KAIA_lendingPoolFactoryProxy)).setOftAddress(KAIA_USDT, KAIA_OFT_USDT_ADAPTER);
        console.log("oftaddress of kaia_usdt after set: ", IFactory(address(KAIA_lendingPoolFactoryProxy)).oftAddress(KAIA_USDT));
        IFactory(address(KAIA_lendingPoolFactoryProxy)).setOftAddress(KAIA_USDT_STARGATE, KAIA_OFT_USDT_STARGATE_ADAPTER);
        IFactory(address(KAIA_lendingPoolFactoryProxy)).setOftAddress(KAIA_KAIA, KAIA_OFT_WKAIA_ADAPTER);
        IFactory(address(KAIA_lendingPoolFactoryProxy)).setOftAddress(KAIA_WKAIA, KAIA_OFT_WKAIA_ADAPTER);
        IFactory(address(KAIA_lendingPoolFactoryProxy)).setOftAddress(KAIA_WETH, KAIA_OFT_WETH_ADAPTER);
        IFactory(address(KAIA_lendingPoolFactoryProxy)).setOftAddress(KAIA_WBTC, KAIA_OFT_WBTC_ADAPTER);
        vm.stopBroadcast();
        console.log("OFT address set successfully!");
    }
}
// RUN
// forge script SetOFTAddress --broadcast -vvv