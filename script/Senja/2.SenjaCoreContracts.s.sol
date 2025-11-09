// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {Liquidator} from "../../src/Liquidator.sol";
import {IsHealthy} from "../../src/IsHealthy.sol";
import {LendingPoolDeployer} from "../../src/LendingPoolDeployer.sol";
import {Protocol} from "../../src/Protocol.sol";
import {PositionDeployer} from "../../src/PositionDeployer.sol";
import {LendingPoolFactory} from "../../src/LendingPoolFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IFactory} from "../../src/interfaces/IFactory.sol";
import {LendingPoolRouterDeployer} from "../../src/LendingPoolRouterDeployer.sol";

contract SenjaCoreContracts is Script, Helper {
    Liquidator public liquidator;
    IsHealthy public isHealthy;
    LendingPoolDeployer public lendingPoolDeployer;
    LendingPoolRouterDeployer public lendingPoolRouterDeployer;
    Protocol public protocol;
    PositionDeployer public positionDeployer;
    LendingPoolFactory public lendingPoolFactory;
    ERC1967Proxy public proxy;

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

    function _getUtils() internal {
        if(block.chainid == 8217) {
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
        }
    }
    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        liquidator = new Liquidator();
        isHealthy = new IsHealthy(address(liquidator));
        lendingPoolDeployer = new LendingPoolDeployer();
        lendingPoolRouterDeployer = new LendingPoolRouterDeployer();
        protocol = new Protocol();
        positionDeployer = new PositionDeployer();

        lendingPoolFactory = new LendingPoolFactory();
        bytes memory data = abi.encodeWithSelector(
            lendingPoolFactory.initialize.selector,
            address(isHealthy),
            address(lendingPoolRouterDeployer),
            address(lendingPoolDeployer),
            address(protocol),
            address(positionDeployer)
        );
        proxy = new ERC1967Proxy(address(lendingPoolFactory), data);

        lendingPoolDeployer.setFactory(address(proxy));
        lendingPoolRouterDeployer.setFactory(address(proxy));

        IFactory(address(proxy)).addTokenDataStream(USDT, USDT_USD_ADAPTER);
        IFactory(address(proxy)).addTokenDataStream(USDT_STARGATE, USDT_USD_ADAPTER);
        IFactory(address(proxy)).addTokenDataStream(WKAIA, KAIA_USDT_ADAPTER);
        IFactory(address(proxy)).addTokenDataStream(KAIA, KAIA_USDT_ADAPTER);
        IFactory(address(proxy)).addTokenDataStream(WETH, ETH_USDT_ADAPTER);
        IFactory(address(proxy)).addTokenDataStream(WBTC, BTC_USDT_ADAPTER);
        vm.stopBroadcast();

        console.log("address public liquidator =", address(liquidator), ";");
        console.log("address public isHealthy =", address(isHealthy), ";");
        console.log("address public lendingPoolDeployer =", address(lendingPoolDeployer), ";");
        console.log("address public protocol =", address(protocol), ";");
        console.log("address public positionDeployer =", address(positionDeployer), ";");
        console.log("address public lendingPoolFactoryImplementation =", address(lendingPoolFactory), ";");
        console.log("address public lendingPoolFactoryProxy =", address(proxy), ";");
    }
}

// RUN
// forge script SenjaCoreContracts --broadcast -vvv
// forge script SenjaCoreContracts -vvv
