// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {MOCKUSDT} from "../../src/MockToken/MOCKUSDT.sol";
import {MOCKWKAIA} from "../../src/MockToken/MOCKWKAIA.sol";
import {MOCKWETH} from "../../src/MockToken/MOCKWETH.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTadapter} from "../../src/layerzero/OFTadapter.sol";
import {MOCKTOKEN} from "../../src/MockToken/MOCKTOKEN.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {STOKEN} from "../../src/BridgeToken/STOKEN.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";

contract DeployAllOFT is Script, Helper {
    using OptionsBuilder for bytes;

    address owner = vm.envAddress("PUBLIC_KEY");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    // Mock tokens
    MOCKUSDT public mockUSDT;
    MOCKWKAIA public mockWKAIA;
    MOCKWETH public mockWETH;
    MOCKTOKEN public mockTOKEN;

    STOKEN public sToken;

    OFTadapter public oftadapter;
    ElevatedMinterBurner public elevatedMinterBurner;

    // State variables
    address public TOKEN;

    address endpoint;
    address oapp;
    address oapp2;
    address sendLib;
    address receiveLib;
    uint32 srcEid;
    uint32 gracePeriod;

    address dvn1;
    address dvn2;
    address executor;

    uint8 public _SHAREDDECIMALS;
    uint32 eid0;
    uint32 eid1;
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;
    uint32 constant RECEIVE_CONFIG_TYPE = 2;
    string chainName;
    bool isDestination;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(privateKey);
        _getUtils();
        // ******************************
        // *********** Step 1 ***********
        // ******************************
        _deployOFT();
        _setLibraries();
        _setSendConfig();
        _setReceiveConfig();
        // ******************************
        // *********** Step 2 ***********
        // ******************************
        // _setPeers();
        // _setEnforcedOptions();
        vm.stopBroadcast();
    }

    function _getUtils() internal {
        if (block.chainid == 8217) {
            chainName = "KAIA";
            endpoint = KAIA_LZ_ENDPOINT;
            sendLib = KAIA_SEND_LIB;
            receiveLib = KAIA_RECEIVE_LIB;
            srcEid = KAIA_EID;
            gracePeriod = uint32(0);
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
            executor = KAIA_EXECUTOR;
            eid0 = KAIA_EID;
            eid1 = BASE_EID; // **
            TOKEN = _deployMockToken("USD Tether", "USDT", 6); // **
            oapp; // **
            oapp2; // **
        } else if (block.chainid == 8453) {
            chainName = "BASE";
            endpoint = BASE_LZ_ENDPOINT;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
            executor = BASE_EXECUTOR;
            eid0 = BASE_EID;
            eid1 = KAIA_EID; // **
            TOKEN = _deployMockToken("USD Tether", "USDT", 6); // **
            oapp; // **
            oapp2; // **
        } else if (block.chainid == 1284) {
            chainName = "GLMR";
            endpoint = GLMR_LZ_ENDPOINT;
            sendLib = GLMR_SEND_LIB;
            receiveLib = GLMR_RECEIVE_LIB;
            srcEid = GLMR_EID;
            gracePeriod = uint32(0);
            dvn1 = GLMR_DVN1;
            dvn2 = GLMR_DVN2;
            executor = GLMR_EXECUTOR;
            eid0 = GLMR_EID;
            eid1 = BASE_EID; // **
            TOKEN = _deployMockToken("USD Tether", "USDT", 6); // **
            oapp; // **
            oapp2; // **
        }
        // TESTNET
        else if (block.chainid == 1001) {
            TOKEN = _deployMockToken("USD Tether", "USDT", 6);
        }
    }

    function _deployMockToken(string memory _name, string memory _symbol, uint8 _decimals) internal returns (address) {
        mockTOKEN = new MOCKTOKEN(_name, _symbol, _decimals);
        return address(mockTOKEN);
    }

    function _deploySTOKEN(string memory _name, string memory _symbol, uint8 _decimals) internal returns (address) {
        sToken = new STOKEN(_name, _symbol, _decimals);
        return address(sToken);
    }

    function _deployOFT() internal {
        elevatedMinterBurner = new ElevatedMinterBurner(TOKEN, owner);
        oftadapter = new OFTadapter(TOKEN, address(elevatedMinterBurner), endpoint, owner, _getDecimals(TOKEN));
        oapp = address(oftadapter);
        elevatedMinterBurner.setOperator(oapp, true);

        console.log(
            "address public %s_%s_ELEVATED_MINTER_BURNER = %s;",
            block.chainid,
            _getSymbol(TOKEN),
            address(elevatedMinterBurner)
        );
        console.log("address public %s_%s_OFT_ADAPTER = %s;", block.chainid, _getSymbol(TOKEN), address(oapp));

        if (isDestination) STOKEN(TOKEN).setOperator(address(elevatedMinterBurner), true);
    }

    function _setLibraries() internal {
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, eid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp, srcEid, receiveLib, gracePeriod);
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
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
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

        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
    }

    function _setPeers() internal {
        bytes32 oftPeer = bytes32(uint256(uint160(address(oapp))));
        bytes32 oftPeer2 = bytes32(uint256(uint160(address(oapp2))));
        OFTadapter(oapp).setPeer(eid0, oftPeer);
        OFTadapter(oapp).setPeer(eid1, oftPeer2);
    }

    function _setEnforcedOptions() internal {
        uint16 SEND = 1;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: eid0, msgType: SEND, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: eid1, msgType: SEND, options: options2});

        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
    }

    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }

    function _getSymbol(address _token) internal view returns (string memory) {
        return IERC20Metadata(_token).symbol();
    }

    function _getDecimals(address _token) internal view returns (uint8) {
        return IERC20Metadata(_token).decimals();
    }
}
// forge script DeployAllOFT --broadcast -vvv --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
// forge script DeployAllOFT --broadcast -vvv
// forge script DeployAllOFT -vvv
