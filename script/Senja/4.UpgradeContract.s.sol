// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {LendingPoolFactory} from "../../src/LendingPoolFactory.sol";
import {Helper} from "../DevTools/Helper.sol";
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

    address USDT;
    address WKAIA;
    address MOCK_WNative;
    address MOCK_USDT;

    address lendingPoolFactoryProxy;

    string chainName;

    function run() external {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        vm.startBroadcast(privateKey);
        // _upgrade();

        _setContract();

        vm.stopBroadcast();
    }

    function _upgrade() internal {
        newImplementation = new LendingPoolFactory();
        LendingPoolFactory(lendingPoolFactoryProxy).upgradeTo(address(newImplementation));

        console.log("address public %s_lendingPoolFactoryImplementation = %s;", chainName, address(newImplementation));
    }

    function _setContract() internal {
        _setupLendingPoolRouterDeployer();
        _setupLiquidatorAndIsHealthy();
        _setupPositionDeployer();
        _setupProtocol();
        _setupLendingPoolDeployer();
        _createLendingPool();
    }

    function _setupLendingPoolRouterDeployer() internal {
        lendingPoolRouterDeployer = new LendingPoolRouterDeployer();
        lendingPoolRouterDeployer.setFactory(lendingPoolFactoryProxy);
        LendingPoolFactory(lendingPoolFactoryProxy).setLendingPoolRouterDeployer(address(lendingPoolRouterDeployer));
        console.log("address public %s_lendingPoolRouterDeployer = %s;", chainName, address(lendingPoolRouterDeployer));
    }

    function _setupLiquidatorAndIsHealthy() internal {
        liquidator = new Liquidator();
        liquidator.setFactory(lendingPoolFactoryProxy);
        isHealthy = new IsHealthy(address(liquidator));
        LendingPoolFactory(lendingPoolFactoryProxy).setIsHealthy(address(isHealthy));
        console.log("address public %s_liquidator = %s;", chainName, address(liquidator));
        console.log("address public %s_isHealthy = %s;", chainName, address(isHealthy));
    }

    function _setupPositionDeployer() internal {
        positionDeployer = new PositionDeployer();
        LendingPoolFactory(lendingPoolFactoryProxy).setPositionDeployer(address(positionDeployer));
        console.log("address public %s_positionDeployer = %s;", chainName, address(positionDeployer));
    }

    function _setupProtocol() internal {
        protocol = new Protocol();
        LendingPoolFactory(lendingPoolFactoryProxy).setProtocol(address(protocol));
        console.log("address public %s_protocol = %s;", chainName, address(protocol));
    }

    function _setupLendingPoolDeployer() internal {
        lendingPoolDeployer = new LendingPoolDeployer();
        lendingPoolDeployer.setFactory(lendingPoolFactoryProxy);
        LendingPoolFactory(lendingPoolFactoryProxy).setLendingPoolDeployer(address(lendingPoolDeployer));
        console.log("address public %s_lendingPoolDeployer = %s;", chainName, address(lendingPoolDeployer));
    }

    function _createLendingPool() internal {
        LendingPoolFactory(lendingPoolFactoryProxy).createLendingPool(MOCK_WNative, MOCK_USDT, 886e15);
    }

    function _getUtils() internal {
        if (block.chainid == 8217) {
            lendingPoolFactoryProxy = lendingPoolFactoryProxy;
            chainName = "KAIA";
            WKAIA = KAIA_WKAIA;
            USDT = KAIA_USDT;
            MOCK_WNative = KAIA_MOCK_WKAIA;
            MOCK_USDT = KAIA_MOCK_USDT;
        }
    }
}

// RUN
//  forge script UpgradeContract --broadcast -vvv
//  forge script UpgradeContract -vvv
