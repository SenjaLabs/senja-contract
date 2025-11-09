// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";
import {Helper} from "../DevTools/Helper.sol";

/// @title LayerZero OApp Peer Configuration Script
/// @notice Sets up peer connections between OApp deployments on different chains
contract SetPeers is Script, Helper {
    function run() external {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // USDT Adapter peers
        MyOApp(BASE_OFT_USDTK_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_USDTK_ADAPTER))));
        MyOApp(BASE_OFT_USDTK_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_USDT_ADAPTER))));

        // WKAIA Adapter peers
        MyOApp(BASE_OFT_WKAIAK_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_WKAIAK_ADAPTER))));
        MyOApp(BASE_OFT_WKAIAK_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WKAIA_ADAPTER))));

        // WBTC Adapter peers
        MyOApp(BASE_OFT_WBTCK_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_WBTCK_ADAPTER))));
        MyOApp(BASE_OFT_WBTCK_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WBTC_ADAPTER))));

        // WETH Adapter peers
        MyOApp(BASE_OFT_WETHK_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_WETHK_ADAPTER))));
        MyOApp(BASE_OFT_WETHK_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WETH_ADAPTER))));

        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_USDT_ADAPTER))));
        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_USDT_ADAPTER))));

        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // USDT Adapter peers
        MyOApp(KAIA_OFT_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_USDTK_ADAPTER))));
        MyOApp(KAIA_OFT_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_USDT_ADAPTER))));

        // USDT Stargate Adapter peers
        MyOApp(KAIA_OFT_USDT_STARGATE_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_USDTK_ADAPTER))));
        MyOApp(KAIA_OFT_USDT_STARGATE_ADAPTER).setPeer(
            KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_USDT_STARGATE_ADAPTER)))
        );

        // WKAIA Adapter peers
        MyOApp(KAIA_OFT_WKAIA_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_WKAIAK_ADAPTER))));
        MyOApp(KAIA_OFT_WKAIA_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WKAIA_ADAPTER))));

        // WBTC Adapter peers
        MyOApp(KAIA_OFT_WBTC_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_WBTCK_ADAPTER))));
        MyOApp(KAIA_OFT_WBTC_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WBTC_ADAPTER))));

        // WETH Adapter peers
        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_USDT_ADAPTER))));
        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_USDT_ADAPTER))));

        vm.stopBroadcast();
    }
}

// RUN
// forge script SetPeers --broadcast -vvv
