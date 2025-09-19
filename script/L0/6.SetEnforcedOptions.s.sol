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

    function run() external {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));

        uint32 dstEid1 = BASE_EID;
        uint32 dstEid2 = KAIA_EID;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid1, msgType: SEND, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid2, msgType: SEND, options: options2});

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOApp(BASE_OFT_USDTK_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_WKAIAK_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_WBTCK_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_WETHK_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        vm.stopBroadcast();

        console.log("deployed on ChainId: ", block.chainid);
        console.log("Enforced options set successfully!");
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        uint32 dstEid1 = KAIA_EID;
        uint32 dstEid2 = BASE_EID;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid1, msgType: SEND, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid2, msgType: SEND, options: options2});

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOApp(KAIA_OFT_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_USDT_STARGATE_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_WKAIA_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_WBTC_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_WETH_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        vm.stopBroadcast();

        console.log("deployed on ChainId: ", block.chainid);
        console.log("Enforced options set successfully!");
    }
}

// RUN
// forge script SetEnforcedOptions --broadcast -vvv
