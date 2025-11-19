// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {sUSDT} from "../../src/BridgeToken/sUSDT.sol";
import {sWKAIA} from "../../src/BridgeToken/sWKAIA.sol";
import {sWBTC} from "../../src/BridgeToken/sWBTC.sol";
import {sKAIA} from "../../src/BridgeToken/sKAIA.sol";
import {sWETH} from "../../src/BridgeToken/sWETH.sol";
import {Helper} from "../DevTools/Helper.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTadapter.sol";
import {OFTKAIAadapter} from "../../src/layerzero/OFTKAIAadapter.sol";
import {OFTWBTCadapter} from "../../src/layerzero/OFTWBTCadapter.sol";
import {OFTWETHadapter} from "../../src/layerzero/OFTWETHadapter.sol";

contract DeployOFT is Script, Helper {
    address owner = vm.envAddress("PUBLIC_KEY");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    sUSDT public susdt;
    sWKAIA public swkaia;
    sWBTC public swbtc;
    sKAIA public skaia;
    sWETH public sweth;
    ElevatedMinterBurner public elevatedminterburner;
    OFTUSDTadapter public oftusdtadapter;
    OFTKAIAadapter public oftkaiaadapter;
    OFTWBTCadapter public oftwbtcadapter;
    OFTWETHadapter public oftwethadapter;

    function run() public {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);

        susdt = new sUSDT();
        console.log("address public BASE_SUSDT =", address(BASE_SUSDT), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SUSDT), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftusdtadapter = new OFTUSDTadapter(address(BASE_SUSDT), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SUSDT_ADAPTER =", address(oftusdtadapter), ";");
        elevatedminterburner.setOperator(address(oftusdtadapter), true);

        skaia = new sKAIA();
        console.log("address public BASE_SKAIA =", address(BASE_SKAIA), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SKAIA), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter = new OFTKAIAadapter(address(BASE_SKAIA), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SKAIA_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);

        swkaia = new sWKAIA();
        console.log("address public BASE_SWKAIA =", address(BASE_SWKAIA), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SWKAIA), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter =
            new OFTKAIAadapter(address(BASE_SWKAIA), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SWKAIA_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);

        swbtc = new sWBTC();
        console.log("address public BASE_WBTCK =", address(BASE_SWBTC), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SWBTC), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftwbtcadapter = new OFTWBTCadapter(address(BASE_SWBTC), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SWBTC_ADAPTER =", address(oftwbtcadapter), ";");
        elevatedminterburner.setOperator(address(oftwbtcadapter), true);

        sweth = new sWETH();
        console.log("address public BASE_SWETH =", address(BASE_SWETH), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SWETH), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftwethadapter = new OFTWETHadapter(address(BASE_SWETH), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SWETH_ADAPTER =", address(oftwethadapter), ";");
        elevatedminterburner.setOperator(address(oftwethadapter), true);

        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);

        oftusdtadapter = new OFTUSDTadapter(KAIA_USDT, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_USDT_ADAPTER =", address(oftusdtadapter), ";");

        oftusdtadapter = new OFTUSDTadapter(KAIA_USDT_STARGATE, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_USDT_STARGATE_ADAPTER =", address(oftusdtadapter), ";");

        oftkaiaadapter = new OFTKAIAadapter(KAIA_KAIA, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_KAIA_ADAPTER =", address(oftkaiaadapter), ";");

        oftkaiaadapter = new OFTKAIAadapter(KAIA_WKAIA, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_WKAIA_ADAPTER =", address(oftkaiaadapter), ";");

        oftwbtcadapter = new OFTWBTCadapter(KAIA_WBTC, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_WBTC_ADAPTER =", address(oftwbtcadapter), ";");

        oftwethadapter = new OFTWETHadapter(KAIA_WETH, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_WETH_ADAPTER =", address(oftwethadapter), ";");
        vm.stopBroadcast();
    }
}
// RUN
// forge script DeployOFT --broadcast -vvv --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
// forge script DeployOFT --broadcast -vvv
// forge script DeployOFT -vvv
