// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {IFactory} from "../../src/interfaces/IFactory.sol";

contract SetOFTAddress is Script, Helper {
    address USDT;
    address USDT_STARGATE;
    address WKAIA;
    address KAIA;
    address WETH;
    address WBTC;

    address USDT_USD_ADAPTER;
    address KAIA_USDT_ADAPTER;
    address ETH_USDT_ADAPTER;
    address BTC_USDT_ADAPTER;

    address lendingPoolFactoryProxy;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        console.log("oftaddress of usdt before set: ", IFactory(address(lendingPoolFactoryProxy)).oftAddress(USDT));
        IFactory(address(lendingPoolFactoryProxy)).setOftAddress(USDT, USDT_USD_ADAPTER);
        console.log("oftaddress of usdt after set: ", IFactory(address(lendingPoolFactoryProxy)).oftAddress(USDT));
        IFactory(address(lendingPoolFactoryProxy)).setOftAddress(USDT_STARGATE, USDT_USD_ADAPTER);
        IFactory(address(lendingPoolFactoryProxy)).setOftAddress(KAIA, KAIA_USDT_ADAPTER);
        IFactory(address(lendingPoolFactoryProxy)).setOftAddress(WKAIA, KAIA_USDT_ADAPTER);
        IFactory(address(lendingPoolFactoryProxy)).setOftAddress(WETH, ETH_USDT_ADAPTER);
        IFactory(address(lendingPoolFactoryProxy)).setOftAddress(WBTC, BTC_USDT_ADAPTER);
        vm.stopBroadcast();
        console.log("OFT address set successfully!");
    }

    function _getUtils() internal {
        if (block.chainid == 8217) {
            USDT = KAIA_USDT;
            USDT_STARGATE = KAIA_USDT_STARGATE;
            WKAIA = KAIA_WKAIA;
            KAIA = KAIA_KAIA;
            WETH = KAIA_WETH;
            WBTC = KAIA_WBTC;
            USDT_USD_ADAPTER = KAIA_usdt_usd_adapter;
            KAIA_USDT_ADAPTER = KAIA_kaia_usdt_adapter;
            ETH_USDT_ADAPTER = KAIA_eth_usdt_adapter;
            BTC_USDT_ADAPTER = KAIA_btc_usdt_adapter;
            lendingPoolFactoryProxy = KAIA_lendingPoolFactoryProxy;
        }
    }
}
// RUN
// forge script SetOFTAddress --broadcast -vvv
