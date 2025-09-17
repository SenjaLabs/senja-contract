// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {LendingPoolRouterDeployer} from "../src/LendingPoolRouterDeployer.sol";
import {Helper} from "../script/L0/Helper.sol";

// RUN
// forge test --match-contract SenjaUpgradeTest --match-test test_upgrade_contract -vvv
contract SenjaUpgradeTest is Test, Helper {
    LendingPoolFactory public newImplementation;
    LendingPoolRouterDeployer public lendingPoolRouterDeployer;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
    }

    function test_upgrade_contract() public {
        vm.startPrank(vm.envAddress("PUBLIC_KEY"));
        console.log("pool count", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).poolCount());
        {
            (address c, address b, address lp) = LendingPoolFactory(KAIA_lendingPoolFactoryProxy).pools(0);
            console.log("pools[0] collateral", c);
            console.log("pools[0] borrow", b);
            console.log("pools[0] lp", lp);
        }
        console.log("ishealth", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).isHealthy());
        console.log("lendingPoolDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).lendingPoolDeployer());
        console.log("protocol", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).protocol());
        console.log("positionDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).positionDeployer());
        console.log("VERSION", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).VERSION());
        console.log("lendingPoolRouterDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).lendingPoolRouterDeployer());
        console.log("USDT", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_USDT));
        console.log("WKAIA", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_WKAIA));
        console.log("KAIA", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_KAIA));
        console.log("ETH", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_WETH));
        console.log("BTC", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_WBTC));
        console.log("****************************");
        newImplementation = new LendingPoolFactory();
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).upgradeTo(address(newImplementation));
        console.log("****************************");
        console.log("pool count", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).poolCount());
        {
            (address c0, address b0, address lp0) = LendingPoolFactory(KAIA_lendingPoolFactoryProxy).pools(0);
            (address c1, address b1, address lp1) = LendingPoolFactory(KAIA_lendingPoolFactoryProxy).pools(1);
            (address c2, address b2, address lp2) = LendingPoolFactory(KAIA_lendingPoolFactoryProxy).pools(2);
            console.log("pools[0] collateral", c0);
            console.log("pools[0] borrow", b0);
            console.log("pools[0] lp", lp0);
            console.log("pools[1] collateral", c1);
            console.log("pools[1] borrow", b1);
            console.log("pools[1] lp", lp1);
            console.log("pools[2] collateral", c2);
            console.log("pools[2] borrow", b2);
            console.log("pools[2] lp", lp2);
        }
        console.log("ishealth", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).isHealthy());
        console.log("lendingPoolDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).lendingPoolDeployer());
        console.log("protocol", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).protocol());
        console.log("positionDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).positionDeployer());
        console.log("VERSION", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).VERSION());
        console.log("lendingPoolRouterDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).lendingPoolRouterDeployer());
        console.log("USDT", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_USDT));
        console.log("WKAIA", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_WKAIA));
        console.log("KAIA", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_KAIA));
        console.log("ETH", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_WETH));
        console.log("BTC", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).tokenDataStream(KAIA_WBTC));

        console.log("****************************");
        lendingPoolRouterDeployer = new LendingPoolRouterDeployer();
        lendingPoolRouterDeployer.setFactory(KAIA_lendingPoolFactoryProxy);
        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).setLendingPoolRouterDeployer(address(lendingPoolRouterDeployer));
        console.log("****************************");

        LendingPoolFactory(KAIA_lendingPoolFactoryProxy).createLendingPool(KAIA_USDT, KAIA_WKAIA, 8e17);
        (address c3, address b3, address lp3) = LendingPoolFactory(KAIA_lendingPoolFactoryProxy).pools(3);
        console.log("pools[3] collateral", c3);
        console.log("pools[3] borrow", b3);
        console.log("pools[3] lp", lp3);
        console.log("lendingPoolRouterDeployer", LendingPoolFactory(KAIA_lendingPoolFactoryProxy).lendingPoolRouterDeployer());
        vm.stopPrank();
    }
}


