// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {USDTk} from "../../src/BridgeToken/USDTk.sol";
import {WKAIAk} from "../../src/BridgeToken/WKAIAk.sol";
import {WBTCk} from "../../src/BridgeToken/WBTCk.sol";
import {KAIAk} from "../../src/BridgeToken/KAIAk.sol";
import {WETHk} from "../../src/BridgeToken/WETHk.sol";
import {Helper} from "./Helper.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTadapter.sol";
import {OFTKAIAadapter} from "../../src/layerzero/OFTKAIAadapter.sol";
import {OFTWBTCadapter} from "../../src/layerzero/OFTWBTCadapter.sol";
import {OFTWETHadapter} from "../../src/layerzero/OFTWETHadapter.sol";

contract DeployOFT is Script, Helper {
    address owner = vm.envAddress("PUBLIC_KEY");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    USDTk public usdtk;
    WKAIAk public wkaiak;
    WBTCk public wbtck;
    KAIAk public kaiak;
    WETHk public wethk;
    ElevatedMinterBurner public elevatedminterburner;
    OFTUSDTadapter public oftusdtadapter;
    OFTKAIAadapter public oftkaiaadapter;
    OFTWBTCadapter public oftwbtcadapter;
    OFTWETHadapter public oftwethadapter;

    function run() public {
        deployBASE();
        // deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);

        // usdtk = new USDTk();
        console.log("address public BASE_USDTK =", address(BASE_USDTK), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_USDTK), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftusdtadapter = new OFTUSDTadapter(address(BASE_USDTK), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_USDTK_ADAPTER =", address(oftusdtadapter), ";");
        elevatedminterburner.setOperator(address(oftusdtadapter), true);

        // kaiak = new KAIAk();
        console.log("address public BASE_KAIAK =", address(BASE_KAIAK), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_KAIAK), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter = new OFTKAIAadapter(address(BASE_KAIAK), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_KAIAK_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);

        // wkaiak = new WKAIAk();
        console.log("address public BASE_WKAIAK =", address(BASE_WKAIAK), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_WKAIAK), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter = new OFTKAIAadapter(address(BASE_WKAIAK), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_WKAIAK_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);

        // wbtck = new WBTCk();
        console.log("address public BASE_WBTCK =", address(BASE_WBTCK), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_WBTCK), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftwbtcadapter = new OFTWBTCadapter(address(BASE_WBTCK), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_WBTCK_ADAPTER =", address(oftwbtcadapter), ";");
        elevatedminterburner.setOperator(address(oftwbtcadapter), true);

        // wethk = new WETHk();
        console.log("address public BASE_WETHK =", address(BASE_WETHK), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_WETHK), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftwethadapter = new OFTWETHadapter(address(BASE_WETHK), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_WETHK_ADAPTER =", address(oftwethadapter), ";");
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

        // oftkaiaadapter = new OFTKAIAadapter(KAIA_KAIA, address(0), KAIA_LZ_ENDPOINT, owner);
        // console.log("address public KAIA_OFT_KAIA_ADAPTER =", address(oftkaiaadapter), ";");

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
