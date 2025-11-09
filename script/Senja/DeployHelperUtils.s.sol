// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {HelperUtils} from "../../src/HelperUtils.sol";

contract DeployHelperUtils is Script, Helper {
    HelperUtils public helperUtils;
    address lendingPoolFactoryProxy;
    string chainName;
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        vm.startBroadcast(privateKey);
        helperUtils = new HelperUtils(address(lendingPoolFactoryProxy));
        console.log("address public %s_HELPER_UTILS = %s;", chainName, address(helperUtils));
        vm.stopBroadcast();

        console.log("HelperUtils deployed successfully!");
    }

    function _getUtils() internal {
        if (block.chainid == 8217) {
            lendingPoolFactoryProxy = KAIA_lendingPoolFactoryProxy;
            chainName = "KAIA";
        }
    }
}

// RUN
// forge script DeployHelperUtils --broadcast -vvv
// forge script DeployHelperUtils -vvv
