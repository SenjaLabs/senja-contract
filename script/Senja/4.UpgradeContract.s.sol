// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {LendingPoolFactory} from "../../src/LendingPoolFactory.sol";
import {Helper} from "../L0/Helper.sol";
import {LendingPoolRouterDeployer} from "../../src/LendingPoolRouterDeployer.sol";
import {LendingPoolDeployer} from "../../src/LendingPoolDeployer.sol";
import {IsHealthy} from "../../src/IsHealthy.sol";
import {Liquidator} from "../../src/Liquidator.sol";
import {PositionDeployer} from "../../src/PositionDeployer.sol";
import {Protocol} from "../../src/Protocol.sol";

contract UpgradeContract is Script, Helper {
    LendingPoolFactory public newImplementation;
    LendingPoolRouterDeployer public lendingPoolRouterDeployer;
    LendingPoolDeployer public lendingPoolDeployer;
    IsHealthy public isHealthy;
    Liquidator public liquidator;
    PositionDeployer public positionDeployer;
    Protocol public protocol;

    address owner = vm.envAddress("PUBLIC_KEY");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    function run() external {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(privateKey);

        // _upgrade();

        _setContract();

        vm.stopBroadcast();
    }

    function _upgrade() internal {
        newImplementation = new LendingPoolFactory();
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).upgradeTo(address(newImplementation));

        console.log("address public KAIA_lendingPoolImplementation =", address(newImplementation), ";");
    }

    function _setContract() internal {
        lendingPoolRouterDeployer = new LendingPoolRouterDeployer();
        lendingPoolRouterDeployer.setFactory(KAIA_lendingPoolFactoryProxy);
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).setLendingPoolRouterDeployer(
            address(lendingPoolRouterDeployer)
        );
        console.log("address public KAIA_lendingPoolRouterDeployer =", address(lendingPoolRouterDeployer), ";");

        liquidator = new Liquidator();
        liquidator.setFactory(KAIA_lendingPoolFactoryProxy);
        isHealthy = new IsHealthy(address(liquidator));
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).setIsHealthy(address(isHealthy));
        console.log("address public KAIA_liquidator =", address(liquidator), ";");
        console.log("address public KAIA_isHealthy =", address(isHealthy), ";");

        positionDeployer = new PositionDeployer();
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).setPositionDeployer(address(positionDeployer));
        console.log("address public KAIA_positionDeployer =", address(positionDeployer), ";");

        protocol = new Protocol();
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).setProtocol(address(protocol));
        console.log("address public KAIA_protocol =", address(protocol), ";");

        lendingPoolDeployer = new LendingPoolDeployer();
        lendingPoolDeployer.setFactory(KAIA_lendingPoolFactoryProxy);
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).setLendingPoolDeployer(address(lendingPoolDeployer));
        console.log("address public KAIA_lendingPoolDeployer =", address(lendingPoolDeployer), ";");

        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).createLendingPool(KAIA_MOCK_WKAIA, KAIA_MOCK_USDT, 86e16);
    }
}

// RUN
//  forge script UpgradeContract --broadcast -vvv
//  forge script UpgradeContract -vvv
