// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTAdapter} from "../../src/layerzero/OFTAdapter.sol";
import {IMintableBurnable} from "@layerzerolabs/oft-evm/contracts/interfaces/IMintableBurnable.sol";
import {Helper} from "./Helper.sol";
import {SrcEidLib} from "../../src/layerzero/SrcEidLib.sol";
import {ISrcEidLib} from "../../src/interfaces/ISrcEidLib.sol";

contract DeployOApp is Script, Helper {
    ElevatedMinterBurner public minterBurner;
    SrcEidLib public srcEidLib;
    OFTAdapter public oapp;

    address owner = vm.envAddress("PUBLIC_KEY");
    address token;
    address endpoint;

    function run() public {
        // deployBASE();
        // deployKAIA();
        // optimism
        // hyperevm
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            token = BASE_USDTk;
            endpoint = BASE_LZ_ENDPOINT;
        } else if (block.chainid == 8217) {
            token = KAIA_USDTk;
            endpoint = KAIA_LZ_ENDPOINT;
        }
    }

    function srcEidInfo() public view returns (ISrcEidLib.SrcEidInfo[] memory) {
        ISrcEidLib.SrcEidInfo[] memory srcEidInfos = new ISrcEidLib.SrcEidInfo[](2);
        srcEidInfos[0] = ISrcEidLib.SrcEidInfo({eid: BASE_EID, decimals: 2});
        srcEidInfos[1] = ISrcEidLib.SrcEidInfo({eid: KAIA_EID, decimals: 2});
        return srcEidInfos;
    }

    function deployBASE() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        _getUtils();
        vm.startBroadcast(privateKey);
        ISrcEidLib.SrcEidInfo[] memory srcEidInfos = srcEidInfo();
        srcEidLib = new SrcEidLib(srcEidInfos, owner);
        minterBurner = new ElevatedMinterBurner(token, owner);
        oapp = new OFTAdapter(
            token, address(minterBurner), IMintableBurnable(token), endpoint, owner, address(srcEidLib)
        );
        minterBurner.setOperator(address(oapp), true);

        vm.stopBroadcast();

        console.log("address public BASE_SRC_EID_LIB =", address(srcEidLib), ";");
        console.log("address public BASE_OAPP =", address(oapp), ";");
        console.log("address public BASE_MINTER_BURNER =", address(minterBurner), ";");
    }

    function deployKAIA() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        _getUtils();
        vm.startBroadcast(privateKey);
        ISrcEidLib.SrcEidInfo[] memory srcEidInfos = srcEidInfo();
        srcEidLib = new SrcEidLib(srcEidInfos, owner);
        minterBurner = new ElevatedMinterBurner(token, owner);
        oapp = new OFTAdapter(
            token, address(minterBurner), IMintableBurnable(token), endpoint, owner, address(srcEidLib)
        );
        minterBurner.setOperator(address(oapp), true);

        vm.stopBroadcast();

        console.log("address public KAIA_SRC_EID_LIB =", address(srcEidLib), ";");
        console.log("address public KAIA_OAPP =", address(oapp), ";");
        console.log("address public KAIA_MINTER_BURNER =", address(minterBurner), ";");
    }
    // RUN
    // forge script DeployOApp --broadcast -vvv --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
    // forge script DeployOApp --broadcast -vvv --verify
}
