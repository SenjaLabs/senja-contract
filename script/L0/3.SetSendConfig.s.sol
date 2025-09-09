// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// mainnet -> check again

import {Script} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {Helper} from "./Helper.sol";

/// @title LayerZero Send Configuration Script (A → B)
/// @notice Defines and applies ULN (DVN) + Executor configs for cross‑chain messages sent from Chain A to Chain B via LayerZero Endpoint V2.
contract SetSendConfig is Script, Helper {
    // destination
    uint32 eid0 = BASE_EID; // Endpoint ID for Chain B
    uint32 eid1 = KAIA_EID; // Endpoint ID for Chain B

    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    address endpoint;
    address oapp;
    address sendLib;
    address dvn1;
    address dvn2;
    address executor;

    /// @notice Helper function to convert fixed-size array to dynamic array
    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }

    function _toDynamicArray1(address[1] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](1);
        dynamicArray[0] = fixedArray[0];
        return dynamicArray;
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            oapp = BASE_OAPP;
            sendLib = BASE_SEND_LIB;
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
            executor = BASE_EXECUTOR;
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            oapp = KAIA_OAPP;
            sendLib = KAIA_SEND_LIB;
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
            executor = KAIA_EXECUTOR;
        }
    }

    /// @notice Broadcasts transactions to set both Send ULN and Executor configurations for messages sent from Chain A to Chain B
    function run() external {
        // deployBASE();
        // deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        _getUtils();
        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold) for A → B
        /// @notice Send config requests these settings to be applied to the DVNs and Executor for messages sent from A to B
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln;
        uln = UlnConfig({
            confirmations: 15, // minimum block confirmations required on A before sending to B
            requiredDVNCount: 2, // number of DVNs required
            optionalDVNCount: type(uint8).max, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: _toDynamicArray([dvn1, dvn2]), // sorted list of required DVN addresses
            optionalDVNs: new address[](0) // sorted list of optional DVNs
        });
        /// @notice ExecutorConfig sets message size limit + fee‑paying executor for A → B
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 10000, // max bytes per cross-chain message
            executor: executor // address that pays destination execution fees on B
        });
        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);
        SetConfigParam[] memory params;
        params = new SetConfigParam[](4);
        params[0] = SetConfigParam(eid0, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid0, ULN_CONFIG_TYPE, encodedUln);
        params[2] = SetConfigParam(eid1, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[3] = SetConfigParam(eid1, ULN_CONFIG_TYPE, encodedUln);
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params); // Set config for messages sent from A to B
        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold) for A → B
        /// @notice Send config requests these settings to be applied to the DVNs and Executor for messages sent from A to B
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln;
        uln = UlnConfig({
            confirmations: 15, // minimum block confirmations required on A before sending to B
            requiredDVNCount: 2, // number of DVNs required
            optionalDVNCount: type(uint8).max, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: _toDynamicArray([dvn1, dvn2]), // sorted list of required DVN addresses
            optionalDVNs: new address[](0) // sorted list of optional DVNs
        });
        /// @notice ExecutorConfig sets message size limit + fee‑paying executor for A → B
        ExecutorConfig memory exec;
        exec = ExecutorConfig({
            maxMessageSize: 10000, // max bytes per cross-chain message
            executor: executor // address that pays destination execution fees on B
        });
        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);
        SetConfigParam[] memory params;
        params = new SetConfigParam[](4);
        params[0] = SetConfigParam(eid0, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid0, ULN_CONFIG_TYPE, encodedUln);
        params[2] = SetConfigParam(eid1, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[3] = SetConfigParam(eid1, ULN_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params); // Set config for messages sent from A to B
        vm.stopBroadcast();
    }
}

// RUN
// forge script SetSendConfig --broadcast -vvv
