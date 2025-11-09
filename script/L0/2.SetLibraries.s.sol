// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Helper} from "../DevTools/Helper.sol";

/// @title LayerZero Library Configuration Script
/// @notice Sets up send and receive libraries for OApp messaging
contract SetLibraries is Script, Helper {
    uint32 dstEid0 = BASE_EID;
    uint32 dstEid1 = KAIA_EID;

    address endpoint;
    address oapp;
    address sendLib;
    address receiveLib;
    uint32 srcEid;
    uint32 gracePeriod;

    function run() external {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
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

        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_USDTK_ADAPTER, dstEid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_WKAIAK_ADAPTER, dstEid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_WBTCK_ADAPTER, dstEid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_WETHK_ADAPTER, dstEid1, sendLib);

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_USDTK_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_WKAIAK_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_WBTCK_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_WETHK_ADAPTER, srcEid, receiveLib, gracePeriod);

        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();

        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_USDT_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_USDT_STARGATE_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_WKAIA_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_WBTC_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_WETH_ADAPTER, dstEid0, sendLib);

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_USDT_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(
            KAIA_OFT_USDT_STARGATE_ADAPTER, srcEid, receiveLib, gracePeriod
        );
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_WKAIA_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_WBTC_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_WETH_ADAPTER, srcEid, receiveLib, gracePeriod);

        vm.stopBroadcast();
    }
}
// RUN
// forge script SetLibraries --broadcast -vvv
// forge script SetLibraries -vvv
