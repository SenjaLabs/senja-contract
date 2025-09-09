// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Helper} from "./Helper.sol";

/// @title LayerZero OApp Enforced Options Configuration Script
/// @notice Sets enforced execution options for specific message types and destinations
contract SetEnforcedOptions is Script, Helper {
    using OptionsBuilder for bytes;

    uint16 SEND = 1; // Message type for sendString function

    function setUp() public {
        // vm.createSelectFork(vm.rpcUrl("base_sepolia"));
        // vm.createSelectFork(vm.rpcUrl("arb_sepolia"));
    }

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

        // Destination chain configurations
        uint32 dstEid1 = BASE_EID; // First destination EID
        uint32 dstEid2 = KAIA_EID; // Second destination EID

        // Build options using OptionsBuilder
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        // Create enforced options array
        EnforcedOptionParam[] memory enforcedOptions;
        enforcedOptions = new EnforcedOptionParam[](2);
        // Set enforced options for first destination
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid1, msgType: SEND, options: options1});
        // Set enforced options for second destination
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid2, msgType: SEND, options: options2});

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
        vm.stopBroadcast();

        console.log("deployed on ChainId: ", block.chainid);
        console.log("Enforced options set successfully!");
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        // Load environment variables
        address oapp = KAIA_OAPP; // Your OApp contract address

        // Destination chain configurations
        uint32 dstEid1 = KAIA_EID; // first destination EID
        uint32 dstEid2 = BASE_EID; // second destination EID
        // Build options using OptionsBuilder
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        // Create enforced options array
        EnforcedOptionParam[] memory enforcedOptions;
        enforcedOptions = new EnforcedOptionParam[](6);
        // Set enforced options for first destination
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid1, msgType: SEND, options: options1});
        // Set enforced options for second destination
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid2, msgType: SEND, options: options2});

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
        vm.stopBroadcast();

        console.log("deployed on ChainId: ", block.chainid);
        console.log("Enforced options set successfully!");
    }
}

// RUN
// forge script SetEnforcedOptions --broadcast -vvv
