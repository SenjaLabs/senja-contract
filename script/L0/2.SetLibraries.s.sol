// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Helper} from "./Helper.sol";

/// @title LayerZero Library Configuration Script
/// @notice Sets up send and receive libraries for OApp messaging
contract SetLibraries is Script, Helper {
    uint32 dstEid0 = BASE_EID; // Destination chain EID
    uint32 dstEid1 = KAIA_EID; // Destination chain EID

    address endpoint;
    address oapp;
    address sendLib;
    address receiveLib;
    uint32 srcEid;
    uint32 gracePeriod;

    function run() external {
        // deployBASE();
        // deployKAIA();
        // optimism
        // hyperevm
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            oapp = BASE_OAPP;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            oapp = KAIA_OAPP;
            sendLib = KAIA_SEND_LIB;
            receiveLib = KAIA_RECEIVE_LIB;
            srcEid = KAIA_EID;
            gracePeriod = uint32(0);
        }
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();

        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp, // OApp address
            dstEid0, // Destination chain EID
            sendLib // SendUln302 address
        );
        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp, // OApp address
            dstEid1, // Destination chain EID
            sendLib // SendUln302 address
        );

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(
            oapp, // OApp address
            srcEid, // Source chain EID
            receiveLib, // ReceiveUln302 address
            gracePeriod // Grace period for library switch
        );

        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();

        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp, // OApp address
            dstEid0, // Destination chain EID
            sendLib // SendUln302 address
        );
        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp, // OApp address
            dstEid1, // Destination chain EID
            sendLib // SendUln302 address
        );

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(
            oapp, // OApp address
            srcEid, // Source chain EID
            receiveLib, // ReceiveUln302 address
            gracePeriod // Grace period for library switch
        );

        vm.stopBroadcast();
    }
}
// RUN
// forge script SetLibraries --broadcast -vvv
