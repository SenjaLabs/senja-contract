// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
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

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
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

        IFactory(address(proxy)).addTokenDataStream(KAIA_USDT, KAIA_usdt_usd_adapter);
        IFactory(address(proxy)).addTokenDataStream(KAIA_USDT_STARGATE, KAIA_usdt_usd_adapter);
        IFactory(address(proxy)).addTokenDataStream(KAIA_WKAIA, KAIA_kaia_usdt_adapter);
        IFactory(address(proxy)).addTokenDataStream(KAIA_KAIA, KAIA_kaia_usdt_adapter);
        IFactory(address(proxy)).addTokenDataStream(KAIA_WETH, KAIA_eth_usdt_adapter);
        IFactory(address(proxy)).addTokenDataStream(KAIA_WBTC, KAIA_btc_usdt_adapter);
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
