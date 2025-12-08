// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MyOApp} from "../../src/layerzero/MyOApp.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Helper} from "../DevTools/Helper.sol";

/// @title LayerZero OApp Enforced Options Configuration Script
/// @notice Sets enforced execution options for specific message types and destinations
/// @dev This script configures gas limits and execution parameters for cross-chain messaging
///      using LayerZero OApp infrastructure. It sets enforced options for multiple token
///      adapters on both BASE and KAIA networks to ensure reliable message delivery.
///      The script uses Foundry's Script functionality for deployment automation.
contract SetEnforcedOptions is Script, Helper {
    using OptionsBuilder for bytes;

    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice Message type identifier for send operations
    /// @dev Used to specify which type of cross-chain message these enforced options apply to.
    ///      Value of 1 corresponds to the sendString function in the OApp contract.
    uint16 send = 1;

    // ========================================
    // MAIN FUNCTIONS
    // ========================================

    /// @notice Main entry point for setting enforced options across all supported chains
    /// @dev Executes the configuration process for BASE and KAIA networks sequentially.
    ///      Additional chains (Optimism, Hyperevm) are commented out for future expansion.
    ///      This function orchestrates the complete setup process across all chains.
    function run() external {
        deployBase();
        deployKaia();
        // optimism
        // hyperevm
    }

    /// @notice Configures enforced options for OApp adapters on BASE network
    /// @dev This function performs the following steps:
    ///      1. Switches to BASE mainnet fork for testing/deployment
    ///      2. Creates enforced option parameters with different gas limits for different destinations:
    ///         - BASE_EID: 80,000 gas for same-chain operations
    ///         - KAIA_EID: 100,000 gas for cross-chain operations to KAIA
    ///      3. Applies these options to all OFT adapters on BASE (sUSDT, sWKAIA, sWBTC, sWETH, MOCK_USDT)
    ///      Higher gas limit for KAIA reflects additional overhead of cross-chain messaging.
    ///      All transactions are broadcast using the private key from environment variables.
    function deployBase() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));

        // Define destination endpoint IDs
        uint32 dstEid1 = BASE_EID;
        uint32 dstEid2 = KAIA_EID;

        // Create execution options with gas limits
        // options1: 80,000 gas for same-chain (BASE to BASE)
        // options2: 100,000 gas for cross-chain (BASE to KAIA)
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        // Construct enforced option parameters array
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid1, msgType: send, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid2, msgType: send, options: options2});

        // Broadcast configuration to all BASE OFT adapters
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOApp(BASE_OFT_SUSDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_SWKAIA_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_SWBTC_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_SWETH_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        vm.stopBroadcast();

        console.log("deployed on ChainId: ", block.chainid);
        console.log("Enforced options set successfully!");
    }

    function deployKaia() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        uint32 dstEid1 = KAIA_EID;
        uint32 dstEid2 = BASE_EID;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid1, msgType: send, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid2, msgType: send, options: options2});

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOApp(KAIA_OFT_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_USDT_STARGATE_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_WKAIA_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_WBTC_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_WETH_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        vm.stopBroadcast();

        console.log("deployed on ChainId: ", block.chainid);
        console.log("Enforced options set successfully!");
    }
}

// RUN
// forge script SetEnforcedOptions --broadcast -vvv
