// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";
import {Helper} from "./Helper.sol";

/// @title LayerZero OApp Peer Configuration Script
/// @notice Sets up peer connections between OApp deployments on different chains
contract SetPeers is Script, Helper {
    function run() external {
        // deployBASE();
        // deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        // Load environment variables
        address oapp = BASE_OAPP; // Your OApp contract address
        // Example: Set peers for different chains
        // Format: (chain EID, peer address in bytes32)
        (uint32 eid1, bytes32 peer1) = (BASE_EID, bytes32(uint256(uint160(BASE_OAPP))));
        (uint32 eid2, bytes32 peer2) = (KAIA_EID, bytes32(uint256(uint160(KAIA_OAPP))));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // Set peers for each chain
        MyOApp(oapp).setPeer(eid1, peer1);
        MyOApp(oapp).setPeer(eid2, peer2);
        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        // Load environment variables
        address oapp = KAIA_OAPP; // Your OApp contract address
        // Example: Set peers for different chains
        // Format: (chain EID, peer address in bytes32)
        (uint32 eid1, bytes32 peer1) = (BASE_EID, bytes32(uint256(uint160(BASE_OAPP))));
        (uint32 eid2, bytes32 peer2) = (KAIA_EID, bytes32(uint256(uint160(KAIA_OAPP))));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // Set peers for each chain
        MyOApp(oapp).setPeer(eid1, peer1);
        MyOApp(oapp).setPeer(eid2, peer2);
        vm.stopBroadcast();
    }
}

// RUN
// forge script SetPeers --broadcast -vvv
