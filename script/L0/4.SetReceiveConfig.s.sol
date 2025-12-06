// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {Helper} from "../DevTools/Helper.sol";

/// @title LayerZero Receive Configuration Script (B ← A)
/// @notice Defines and applies ULN (DVN) config for inbound message verification on Chain B for messages received from Chain A via LayerZero Endpoint V2.
/// @dev This script configures the receive-side (inbound) message verification settings for LayerZero OFT adapters
///      across multiple chains (Base and Kaia). It sets up DVN (Decentralized Verifier Network) configurations
///      to ensure secure cross-chain message receipt and verification.
contract SetReceiveConfig is Script, Helper {
    // ========================================
    // CONSTANTS
    // ========================================

    /// @notice Configuration type identifier for receive (inbound) configurations in LayerZero protocol
    /// @dev Type 2 represents receive library configuration in IMessageLibManager
    uint32 constant RECEIVE_CONFIG_TYPE = 2;

    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice Endpoint ID for Base chain (destination chain)
    /// @dev Used to configure cross-chain communication parameters for Base network
    uint32 eid0 = BASE_EID;

    /// @notice Endpoint ID for Kaia chain (destination chain)
    /// @dev Used to configure cross-chain communication parameters for Kaia network
    uint32 eid1 = KAIA_EID;

    /// @notice Address of the LayerZero endpoint contract on the current chain
    /// @dev Set dynamically based on the chain ID in _getUtils() function
    address endpoint;

    /// @notice Address of the OApp (Omnichain Application) being configured
    /// @dev Currently unused but reserved for future OApp-specific configurations
    address oapp;

    /// @notice Address of the receive message library contract
    /// @dev Handles inbound message verification and processing on the current chain
    address receiveLib;

    /// @notice Address of the first required DVN (Decentralized Verifier Network)
    /// @dev Part of the required DVN set for message verification, chain-specific
    address dvn1;

    /// @notice Address of the second required DVN (Decentralized Verifier Network)
    /// @dev Part of the required DVN set for message verification, chain-specific
    address dvn2;

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
            receiveLib = BASE_RECEIVE_LIB;
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            receiveLib = KAIA_RECEIVE_LIB;
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
        }
    }

    function run() external {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        _getUtils();
        UlnConfig memory uln;
        uln = UlnConfig({
            confirmations: 15, // min block confirmations from source (A)
            requiredDVNCount: 2, // required DVNs for message acceptance
            optionalDVNCount: type(uint8).max, // optional DVNs count
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: _toDynamicArray([dvn1, dvn2]), // sorted required DVNs
            optionalDVNs: new address[](0) // no optional DVNs
        });
        bytes memory encodedUln = abi.encode(uln);
        SetConfigParam[] memory params;
        params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid0, RECEIVE_CONFIG_TYPE, encodedUln);
        params[1] = SetConfigParam(eid1, RECEIVE_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SUSDT_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SWKAIA_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SWBTC_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(BASE_OFT_SWETH_ADAPTER, receiveLib, params);
        vm.stopBroadcast();
    }

    function deployKAIA() public {
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
        bytes memory encodedUln = abi.encode(uln);
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid0, RECEIVE_CONFIG_TYPE, encodedUln);
        params[1] = SetConfigParam(eid1, RECEIVE_CONFIG_TYPE, encodedUln);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_USDT_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_USDT_STARGATE_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_WKAIA_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_WBTC_ADAPTER, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OFT_WETH_ADAPTER, receiveLib, params);
        vm.stopBroadcast();
    }
}

// RUN
// forge script SetReceiveConfig --broadcast -vvv
// forge script SetReceiveConfig -vvv
