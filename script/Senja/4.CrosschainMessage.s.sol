// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {OAppSupplyLiquidityUSDT} from "../../src/layerzero/messages/OAppSupplyLiquidityUSDT.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {OAppAdapter} from "../../src/layerzero/messages/OAppAdapter.sol";

contract CrosschainMessage is Script, Helper {
    using OptionsBuilder for bytes;

    address owner = vm.envAddress("PUBLIC_KEY");

    OAppSupplyLiquidityUSDT public oappSupplyLiquidityUsdt;
    OAppAdapter public oappAdapter;

    address endpoint;
    address sendLib;
    address receiveLib;
    uint32 srcEid;
    uint32 gracePeriod;

    address dvn1;
    address dvn2;
    address executor;

    uint32 eid0;
    uint32 eid1;
    uint32 dstEid0;
    uint32 dstEid1;
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    function run() external {
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();
        // _deployOApp();
        // _setLibraries();
        // _setSendConfig();
        // _setReceiveConfig();
        // _setPeers();
        // _setEnforcedOptions();
        // _setOftAddress();
        // _deployOappAdapter();
        // _setOFTToken();
        vm.stopBroadcast();
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
            dstEid0 = BASE_EID;
            dstEid1 = KAIA_EID;
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
            dstEid0 = KAIA_EID;
            dstEid1 = BASE_EID;
        }
    }

    function _deployOApp() internal {
        oappSupplyLiquidityUsdt = new OAppSupplyLiquidityUSDT(endpoint, owner);
        if (block.chainid == 8453) {
            console.log("address public BASE_OAPP_SUPPLY_LIQUIDITY_USDT =", address(oappSupplyLiquidityUsdt), ";");
        } else if (block.chainid == 8217) {
            console.log("address public KAIA_OAPP_SUPPLY_LIQUIDITY_USDT =", address(oappSupplyLiquidityUsdt), ";");
        }
    }

    function _setLibraries() internal {
        if (block.chainid == 8453) {
            ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OAPP_SUPPLY_LIQUIDITY_USDT, eid0, sendLib);
            ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OAPP_SUPPLY_LIQUIDITY_USDT, eid1, sendLib);
            ILayerZeroEndpointV2(endpoint)
                .setReceiveLibrary(BASE_OAPP_SUPPLY_LIQUIDITY_USDT, srcEid, receiveLib, gracePeriod);
        } else if (block.chainid == 8217) {
            ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT, eid0, sendLib);
            ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT, eid1, sendLib);
            ILayerZeroEndpointV2(endpoint)
                .setReceiveLibrary(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT, srcEid, receiveLib, gracePeriod);
        }
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
        params[0] = SetConfigParam({eid: eid0, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[1] = SetConfigParam({eid: eid0, configType: ULN_CONFIG_TYPE, config: encodedUln});
        params[2] = SetConfigParam({eid: eid1, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[3] = SetConfigParam({eid: eid1, configType: ULN_CONFIG_TYPE, config: encodedUln});
        if (block.chainid == 8453) {
            ILayerZeroEndpointV2(endpoint).setConfig(BASE_OAPP_SUPPLY_LIQUIDITY_USDT, sendLib, params);
        } else if (block.chainid == 8217) {
            ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT, sendLib, params);
        }
    }

    function _setReceiveConfig() internal {
        uint32 receiveConfigType = 2;

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
        params[0] = SetConfigParam({eid: eid0, configType: receiveConfigType, config: encodedUln});
        params[1] = SetConfigParam({eid: eid1, configType: receiveConfigType, config: encodedUln});

        if (block.chainid == 8453) {
            ILayerZeroEndpointV2(endpoint).setConfig(BASE_OAPP_SUPPLY_LIQUIDITY_USDT, receiveLib, params);
        } else if (block.chainid == 8217) {
            ILayerZeroEndpointV2(endpoint).setConfig(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT, receiveLib, params);
        }
    }

    function _setPeers() internal {
        bytes32 oftPeer = bytes32(uint256(uint160(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT)));
        bytes32 oftPeer2 = bytes32(uint256(uint160(BASE_OAPP_SUPPLY_LIQUIDITY_USDT)));
        if (block.chainid == 8453) {
            OAppSupplyLiquidityUSDT(BASE_OAPP_SUPPLY_LIQUIDITY_USDT).setPeer(KAIA_EID, oftPeer);
            OAppSupplyLiquidityUSDT(BASE_OAPP_SUPPLY_LIQUIDITY_USDT).setPeer(BASE_EID, oftPeer2);
        } else if (block.chainid == 8217) {
            OAppSupplyLiquidityUSDT(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT).setPeer(KAIA_EID, oftPeer);
            OAppSupplyLiquidityUSDT(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT).setPeer(BASE_EID, oftPeer2);
        }
    }

    function _setEnforcedOptions() internal {
        uint16 send = 1;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid0, msgType: send, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid1, msgType: send, options: options2});
        if (block.chainid == 8453) {
            OAppSupplyLiquidityUSDT(BASE_OAPP_SUPPLY_LIQUIDITY_USDT).setEnforcedOptions(enforcedOptions);
        } else if (block.chainid == 8217) {
            OAppSupplyLiquidityUSDT(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT).setEnforcedOptions(enforcedOptions);
        }
    }

    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }

    function _setOftAddress() internal {
        if (block.chainid == 8453) {
            OAppSupplyLiquidityUSDT(BASE_OAPP_SUPPLY_LIQUIDITY_USDT).setOftAddress(BASE_OFT_SUSDT_ADAPTER);
        } else if (block.chainid == 8217) {
            OAppSupplyLiquidityUSDT(KAIA_OAPP_SUPPLY_LIQUIDITY_USDT).setOftAddress(KAIA_OFT_MOCK_USDT_ADAPTER);
        }
    }

    function _deployOappAdapter() internal {
        oappAdapter = new OAppAdapter();
        if (block.chainid == 8453) {
            console.log("address public BASE_OAPP_ADAPTER =", address(oappAdapter), ";");
        } else if (block.chainid == 8217) {
            console.log("address public KAIA_oappAdapter =", address(oappAdapter), ";");
        }
    }

    function _addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }
}

// RUN
//  forge script CrosschainMessage --broadcast -vvv
//  forge script CrosschainMessage -vvv
