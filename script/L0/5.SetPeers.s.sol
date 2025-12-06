// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";
import {Helper} from "../DevTools/Helper.sol";

/// @title LayerZero OApp Peer Configuration Script
/// @notice Deployment script for configuring peer connections between OApp deployments across different chains
/// @dev This script establishes bidirectional peer relationships for LayerZero OFT adapters on BASE and KAIA networks.
///      Peer connections enable cross-chain token transfers by mapping local adapter addresses to their remote counterparts.
///      Each adapter must be configured with both its own endpoint ID (for self-reference) and remote endpoint IDs.
/// @dev Inherits from Forge's Script for deployment capabilities and Helper for chain constants and addresses
contract SetPeers is Script, Helper {
    /// @notice Main entry point for the peer configuration script
    /// @dev Executes peer setup for all supported chains in sequence
    ///      Currently configures BASE and KAIA mainnet deployments
    ///      Additional chains (Optimism, HyperEVM) are commented out for future implementation
    function run() external {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    /// @notice Configures peer connections for all OFT adapters deployed on BASE mainnet
    /// @dev This function sets up bidirectional peer mappings for BASE chain adapters
    ///      Each adapter is configured with two peers:
    ///      1. Self-peer (BASE_EID) - Maps to its own address for local operations
    ///      2. Remote peer (KAIA_EID) - Maps to the corresponding adapter on KAIA chain
    /// @dev Uses vm.createSelectFork to switch to BASE mainnet RPC
    ///      Broadcasts transactions using the PRIVATE_KEY environment variable
    /// @dev Security consideration: Ensure PRIVATE_KEY has sufficient permissions and ETH for gas
    /// @dev Adapters configured: sUSDT, sWKAIA, sWBTC, sWETH, and Mock USDT
    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // USDT Adapter peers
        // Configure sUSDT adapter to recognize itself on BASE and USDT adapter on KAIA
        MyOApp(BASE_OFT_SUSDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SUSDT_ADAPTER))));
        MyOApp(BASE_OFT_SUSDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_USDT_ADAPTER))));

        // WKAIA Adapter peers
        // Configure sWKAIA adapter to recognize itself on BASE and WKAIA adapter on KAIA
        MyOApp(BASE_OFT_SWKAIA_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SWKAIA_ADAPTER))));
        MyOApp(BASE_OFT_SWKAIA_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WKAIA_ADAPTER))));

        // WBTC Adapter peers
        // Configure sWBTC adapter to recognize itself on BASE and WBTC adapter on KAIA
        MyOApp(BASE_OFT_SWBTC_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SWBTC_ADAPTER))));
        MyOApp(BASE_OFT_SWBTC_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WBTC_ADAPTER))));

        // WETH Adapter peers
        // Configure sWETH adapter to recognize itself on BASE and WETH adapter on KAIA
        MyOApp(BASE_OFT_SWETH_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SWETH_ADAPTER))));
        MyOApp(BASE_OFT_SWETH_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WETH_ADAPTER))));

        // Mock USDT Adapter peers (for testing purposes)
        // Configure mock USDT adapter to recognize itself on BASE and mock USDT adapter on KAIA
        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_USDT_ADAPTER))));
        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_USDT_ADAPTER))));

        vm.stopBroadcast();
    }

    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // USDT Adapter peers
        MyOApp(KAIA_OFT_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SUSDT_ADAPTER))));
        MyOApp(KAIA_OFT_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_USDT_ADAPTER))));

        // USDT Stargate Adapter peers
        MyOApp(KAIA_OFT_USDT_STARGATE_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SUSDT_ADAPTER))));
        MyOApp(KAIA_OFT_USDT_STARGATE_ADAPTER)
            .setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_USDT_STARGATE_ADAPTER))));

        // WKAIA Adapter peers
        MyOApp(KAIA_OFT_WKAIA_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SWKAIA_ADAPTER))));
        MyOApp(KAIA_OFT_WKAIA_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WKAIA_ADAPTER))));

        // WBTC Adapter peers
        MyOApp(KAIA_OFT_WBTC_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_SWBTC_ADAPTER))));
        MyOApp(KAIA_OFT_WBTC_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_WBTC_ADAPTER))));

        // WETH Adapter peers
        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_USDT_ADAPTER))));
        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_USDT_ADAPTER))));

        vm.stopBroadcast();
    }
}

// RUN
// forge script SetPeers --broadcast -vvv
