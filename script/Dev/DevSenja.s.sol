// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
import {MOCKUSDT} from "../../src/MockToken/MOCKUSDT.sol";
import {MOCKWKAIA} from "../../src/MockToken/MOCKWKAIA.sol";
import {IFactory} from "../../src/interfaces/IFactory.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTadapter.sol";
import {OFTKAIAadapter} from "../../src/layerzero/OFTKAIAadapter.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";

contract DevSenja is Script, Helper {
    using OptionsBuilder for bytes;

    MOCKUSDT public mockUSDT;
    MOCKWKAIA public mockWKAIA;

    ElevatedMinterBurner public elevatedminterburner;
    OFTUSDTadapter public oftusdtadapter;
    OFTKAIAadapter public oftkaiaadapter;

    address public oftusdt;
    address public oftwkaia;

    address public owner = vm.envAddress("PUBLIC_KEY");

    uint32 dstEid0 = BASE_EID; // Destination chain EID
    uint32 dstEid1 = KAIA_EID; // Destination chain EID

    address endpoint;
    address oapp;
    address oapp2;
    address oapp3;
    address sendLib;
    address receiveLib;
    uint32 srcEid;
    uint32 gracePeriod;

    address dvn1;
    address dvn2;
    address executor;

    uint32 eid0;
    uint32 eid1;

    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;
    uint32 constant RECEIVE_CONFIG_TYPE = 2;
    uint16 SEND = 1; // Message type for sendString function

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _deployTokens();
        _getUtils();
        _deployOFT();
        _setLibraries();
        _setSendConfig();
        _setReceiveConfig();
        _setPeers();
        _setEnforcedOFT();
        _setOFTAddress();
        vm.stopBroadcast();
    }

    function _deployTokens() internal {
        mockUSDT = new MOCKUSDT();
        mockWKAIA = new MOCKWKAIA();
        console.log("address public BASE_mockUSDT =", address(mockUSDT), ";");
        console.log("address public BASE_mockWKAIA =", address(mockWKAIA), ";");
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
            executor = BASE_EXECUTOR;
            eid0 = BASE_EID;
            eid1 = KAIA_EID;
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            sendLib = KAIA_SEND_LIB;
            receiveLib = KAIA_RECEIVE_LIB;
            srcEid = KAIA_EID;
            gracePeriod = uint32(0);
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
            executor = KAIA_EXECUTOR;
            eid0 = BASE_EID;
            eid1 = KAIA_EID;
        }
    }

    function _deployOFT() internal {
        elevatedminterburner = new ElevatedMinterBurner(address(KAIA_MOCK_USDT), owner);
        console.log("address public KAIA_MOCK_USDT_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftusdtadapter =
            new OFTUSDTadapter(address(KAIA_MOCK_USDT), address(elevatedminterburner), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_MOCK_USDT_ADAPTER =", address(oftusdtadapter), ";");
        elevatedminterburner.setOperator(address(oftusdtadapter), true);
        oftusdt = address(oftusdtadapter);

        elevatedminterburner = new ElevatedMinterBurner(KAIA_MOCK_WKAIA, owner);
        console.log("address public KAIA_MOCK_WKAIA_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter =
            new OFTKAIAadapter(KAIA_MOCK_WKAIA, address(elevatedminterburner), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_MOCK_WKAIA_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);
        oftwkaia = address(oftkaiaadapter);
    }

    function _setLibraries() internal {
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oftusdt, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oftwkaia, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oftusdt, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oftwkaia, srcEid, receiveLib, gracePeriod);
    }

    function _setSendConfig() internal {
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
        params[0] = SetConfigParam(eid0, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid0, ULN_CONFIG_TYPE, encodedUln);
        params[2] = SetConfigParam(eid1, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[3] = SetConfigParam(eid1, ULN_CONFIG_TYPE, encodedUln);

        ILayerZeroEndpointV2(endpoint).setConfig(oftusdt, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(oftwkaia, sendLib, params);
    }

    function _setReceiveConfig() internal {
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

        ILayerZeroEndpointV2(endpoint).setConfig(oftusdt, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(oftwkaia, receiveLib, params);
    }

    function _setPeers() internal {
        // MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_USDT_ADAPTER))));
        // MyOApp(KAIA_OFT_MOCK_WKAIA_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_WKAIA_ADAPTER))));

        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_USDT_ADAPTER))));
        MyOApp(BASE_OFT_MOCK_WKAIA_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_WKAIA_ADAPTER))));
    }

    function _setEnforcedOFT() internal {
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: eid0, msgType: SEND, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: eid1, msgType: SEND, options: options2});

        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_MOCK_WKAIA_ADAPTER).setEnforcedOptions(enforcedOptions);
    }

    function _setOFTAddress() internal {
        IFactory(KAIA_lendingPoolFactoryProxy).setOftAddress(KAIA_MOCK_USDT, oftusdt);
        IFactory(KAIA_lendingPoolFactoryProxy).setOftAddress(KAIA_MOCK_WKAIA, oftwkaia);
    }

    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }
}

// RUN
// forge script DevSenja --broadcast -vvv