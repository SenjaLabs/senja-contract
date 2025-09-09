// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {USDTk} from "../../src/BridgeToken/USDTk.sol";
import {Helper} from "./Helper.sol";

contract DeployOFT is Script, Helper {
    address owner = vm.envAddress("PUBLIC_KEY");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    function run() public {
        // deployBASE();
        // deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);
        USDTk usdtk = new USDTk();
        console.log("address public BASE_USDTk =", address(usdtk), ";");

        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);
        USDTk usdtk = new USDTk();
        console.log("address public KAIA_USDTk =", address(usdtk), ";");

        vm.stopBroadcast();
    }
}
// RUN
// forge script DeployOFT --broadcast -vvv --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
// forge script DeployOFT --broadcast -vvv --verify
