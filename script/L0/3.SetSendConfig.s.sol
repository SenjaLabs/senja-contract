// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// mainnet -> check again

import {Script} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {Helper} from "../DevTools/Helper.sol";

/// @title LayerZero Send Configuration Script (A → B)
/// @notice Defines and applies ULN (DVN) + Executor configs for cross‑chain messages sent from Chain A to Chain B via LayerZero Endpoint V2.
/// @dev This script configures the send libraries and DVN settings for OFT adapters on BASE and KAIA chains.
///      It sets up both ULN (Ultra Light Node) configuration with DVNs (Decentralized Verifier Networks)
///      and Executor configuration for message size limits. The script uses Foundry's forge script
///      capabilities to broadcast transactions to mainnet networks.
contract SetSendConfig is Script, Helper {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The owner address loaded from the PUBLIC_KEY environment variable
    /// @dev Used for verification and authorization purposes
    address owner = vm.envAddress("PUBLIC_KEY");

    /// @notice The private key loaded from environment for transaction signing
    /// @dev Used in vm.startBroadcast() to sign and send transactions
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    /// @notice The endpoint ID for BASE chain
    /// @dev Loaded from Helper contract constants
    uint32 eid0 = BASE_EID;

    /// @notice The endpoint ID for KAIA chain
    /// @dev Loaded from Helper contract constants
    uint32 eid1 = KAIA_EID;

    /// @notice Configuration type identifier for Executor configuration
    /// @dev Used in SetConfigParam to specify the type of configuration being set
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;

    /// @notice Configuration type identifier for ULN (Ultra Light Node) configuration
    /// @dev Used in SetConfigParam to specify the type of configuration being set
    uint32 constant ULN_CONFIG_TYPE = 2;

    /// @notice The LayerZero endpoint address for the current chain
    /// @dev Set dynamically in _getUtils() based on block.chainid
    address endpoint;

    /// @notice The send library address for the current chain
    /// @dev Set dynamically in _getUtils() based on block.chainid
    address sendLib;

    /// @notice The first Decentralized Verifier Network (DVN) address
    /// @dev Set dynamically in _getUtils() based on block.chainid
    address dvn1;

    /// @notice The second Decentralized Verifier Network (DVN) address
    /// @dev Set dynamically in _getUtils() based on block.chainid
    address dvn2;

    /// @notice The executor address for processing cross-chain messages
    /// @dev Set dynamically in _getUtils() based on block.chainid
    address executor;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a fixed-size array of 2 addresses to a dynamic array
    /// @dev This is required because LayerZero UlnConfig expects dynamic arrays for DVN addresses
    /// @param fixedArray The fixed-size array containing 2 addresses
    /// @return dynamicArray A dynamic array containing the same addresses
    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }

    /// @notice Converts a fixed-size array of 1 address to a dynamic array
    /// @dev This is a utility function for cases where only one DVN address is needed
    /// @param fixedArray The fixed-size array containing 1 address
    /// @return dynamicArray A dynamic array containing the same address
    function _toDynamicArray1(address[1] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](1);
        dynamicArray[0] = fixedArray[0];
        return dynamicArray;
    }

    /// @notice Loads chain-specific LayerZero configuration addresses based on the current chain ID
    /// @dev Populates endpoint, sendLib, dvn1, dvn2, and executor state variables.
    ///      Supports BASE (chain ID 8453) and KAIA (chain ID 8217) networks.
    ///      All addresses are loaded from the Helper contract constants.
    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            sendLib = BASE_SEND_LIB;
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
            executor = BASE_EXECUTOR;
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            sendLib = KAIA_SEND_LIB;
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
            executor = KAIA_EXECUTOR;
        }
    }

    /// @notice Broadcasts transactions to set both Send ULN and Executor configurations for messages sent from Chain A to Chain B
    function run() external {
        deployBase();
        deployKaia();
        // optimism
        // hyperevm
    }

    function deployBase() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        _getUtils();
        UlnConfig memory uln = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: _toDynamicArray([dvn1, dvn2]),
            optionalDVNs: new address[](0)
        });
        ExecutorConfig memory exec = ExecutorConfig({maxMessageSize: 10000, executor: executor});
        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);
        SetConfigParam[] memory params = new SetConfigParam[](4);
        params[0] = SetConfigParam({eid: eid0, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[1] = SetConfigParam({eid: eid0, configType: ULN_CONFIG_TYPE, config: encodedUln});
        params[2] = SetConfigParam({eid: eid1, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[3] = SetConfigParam({eid: eid1, configType: ULN_CONFIG_TYPE, config: encodedUln});
        vm.startBroadcast(privateKey);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SUSDT_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SWKAIA_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SWBTC_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SWETH_ADAPTER, sendLib, params);
        vm.stopBroadcast();
    }

    function deployKaia() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        UlnConfig memory uln = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: _toDynamicArray([dvn1, dvn2]),
            optionalDVNs: new address[](0)
        });
        ExecutorConfig memory exec = ExecutorConfig({maxMessageSize: 10000, executor: executor});
        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);
        SetConfigParam[] memory params = new SetConfigParam[](4);
        params[0] = SetConfigParam({eid: eid0, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[1] = SetConfigParam({eid: eid0, configType: ULN_CONFIG_TYPE, config: encodedUln});
        params[2] = SetConfigParam({eid: eid1, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[3] = SetConfigParam({eid: eid1, configType: ULN_CONFIG_TYPE, config: encodedUln});
        vm.startBroadcast(privateKey);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_USDT_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_USDT_STARGATE_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_WKAIA_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_WBTC_ADAPTER, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_WETH_ADAPTER, sendLib, params);
        vm.stopBroadcast();
    }
}

// RUN
// forge script SetSendConfig --broadcast -vvv
// forge script SetSendConfig -vvv
