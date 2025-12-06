// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
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

/**
 * @title DevSenja
 * @notice Deployment script for setting up Senja protocol with LayerZero OFT adapters and cross-chain infrastructure
 * @dev This script deploys mock tokens, OFT adapters, and configures LayerZero cross-chain messaging between BASE and KAIA networks.
 *      It handles the complete setup including:
 *      - Mock token deployment (USDT and WKAIA)
 *      - ElevatedMinterBurner contracts for controlled minting/burning
 *      - OFT adapters for cross-chain token transfers
 *      - LayerZero endpoint configuration (libraries, DVNs, executors)
 *      - Peer relationships between chains
 *      - Enforced options for message execution
 *      This script is intended for development and testing purposes only.
 */
contract DevSenja is Script, Helper {
    using OptionsBuilder for bytes;

    // ========================================
    // STATE VARIABLES - Mock Tokens
    // ========================================

    /// @notice Mock USDT token contract instance
    MOCKUSDT public mockUSDT;

    /// @notice Mock Wrapped KAIA token contract instance
    MOCKWKAIA public mockWKAIA;

    // ========================================
    // STATE VARIABLES - LayerZero Components
    // ========================================

    /// @notice ElevatedMinterBurner contract for controlled token minting and burning
    ElevatedMinterBurner public elevatedminterburner;

    /// @notice OFT adapter for USDT cross-chain transfers
    OFTUSDTadapter public oftusdtadapter;

    /// @notice OFT adapter for WKAIA cross-chain transfers
    OFTKAIAadapter public oftkaiaadapter;

    /// @notice Address of the deployed USDT OFT adapter
    address public oftusdt;

    /// @notice Address of the deployed WKAIA OFT adapter
    address public oftwkaia;

    // ========================================
    // STATE VARIABLES - Configuration
    // ========================================

    /// @notice Owner address loaded from environment variable PUBLIC_KEY
    address public owner = vm.envAddress("PUBLIC_KEY");

    /// @notice Destination chain endpoint identifier for BASE network
    uint32 dstEid0 = BASE_EID;

    /// @notice Destination chain endpoint identifier for KAIA network
    uint32 dstEid1 = KAIA_EID;

    /// @notice LayerZero endpoint address for the current chain
    address endpoint;

    /// @notice First OApp instance address
    address oapp;

    /// @notice Second OApp instance address
    address oapp2;

    /// @notice Third OApp instance address
    address oapp3;

    /// @notice Send library address for LayerZero messaging
    address sendLib;

    /// @notice Receive library address for LayerZero messaging
    address receiveLib;

    /// @notice Source chain endpoint identifier
    uint32 srcEid;

    /// @notice Grace period for library upgrades (set to 0 for immediate effect)
    uint32 gracePeriod;

    /// @notice First Decentralized Verifier Network (DVN) address
    address dvn1;

    /// @notice Second Decentralized Verifier Network (DVN) address
    address dvn2;

    /// @notice Executor address for LayerZero message execution
    address executor;

    /// @notice First endpoint identifier used in configuration
    uint32 eid0;

    /// @notice Second endpoint identifier used in configuration
    uint32 eid1;

    // ========================================
    // CONSTANTS
    // ========================================

    /// @notice Configuration type identifier for executor configuration
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;

    /// @notice Configuration type identifier for ULN (Ultra Light Node) configuration
    uint32 constant ULN_CONFIG_TYPE = 2;

    /// @notice Configuration type identifier for receive configuration
    uint32 constant RECEIVE_CONFIG_TYPE = 2;

    /// @notice Message type identifier for sendString function
    uint16 SEND = 1;

    // ========================================
    // MAIN EXECUTION
    // ========================================

    /**
     * @notice Main execution function that orchestrates the complete deployment and configuration process
     * @dev Executes the following steps in sequence:
     *      1. Creates and selects a fork of KAIA mainnet
     *      2. Starts broadcasting transactions with the deployer's private key
     *      3. Deploys mock tokens (USDT and WKAIA)
     *      4. Retrieves chain-specific utilities and addresses
     *      5. Deploys OFT adapters and elevated minter/burner contracts
     *      6. Configures LayerZero libraries (send and receive)
     *      7. Sets send configuration (DVNs and executor)
     *      8. Sets receive configuration
     *      9. Establishes peer relationships between chains
     *      10. Sets enforced options for cross-chain messages
     *      11. Registers OFT addresses with the lending pool factory
     *      12. Stops broadcasting transactions
     */
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

    // ========================================
    // INTERNAL FUNCTIONS - Deployment
    // ========================================

    /**
     * @notice Deploys mock token contracts for USDT and WKAIA
     * @dev Creates new instances of MOCKUSDT and MOCKWKAIA contracts and logs their addresses
     *      to the console for reference in subsequent deployment steps
     */
    function _deployTokens() internal {
        mockUSDT = new MOCKUSDT();
        mockWKAIA = new MOCKWKAIA();
        console.log("address public BASE_mockUSDT =", address(mockUSDT), ";");
        console.log("address public BASE_mockWKAIA =", address(mockWKAIA), ";");
    }

    /**
     * @notice Retrieves and sets chain-specific utilities and configuration addresses
     * @dev Configures the following based on the current chain ID:
     *      - For BASE (chain ID 8453):
     *        - Sets LayerZero endpoint, send/receive libraries
     *        - Configures source and destination EIDs
     *        - Sets DVN addresses and executor
     *      - For KAIA (chain ID 8217):
     *        - Sets LayerZero endpoint, send/receive libraries
     *        - Configures source and destination EIDs
     *        - Sets DVN addresses and executor
     *      The grace period is set to 0 for immediate library upgrades
     */
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

    /**
     * @notice Deploys OFT adapters and ElevatedMinterBurner contracts for cross-chain token transfers
     * @dev Performs the following for both USDT and WKAIA:
     *      1. Deploys an ElevatedMinterBurner contract with the mock token and owner
     *      2. Deploys an OFT adapter with the mock token, minter/burner, endpoint, and owner
     *      3. Sets the OFT adapter as an authorized operator on the minter/burner
     *      4. Stores the OFT adapter address for later configuration
     *
     *      For USDT:
     *      - Uses KAIA_MOCK_USDT as the underlying token
     *      - Deploys OFTUSDTadapter
     *
     *      For WKAIA:
     *      - Uses KAIA_MOCK_WKAIA as the underlying token
     *      - Deploys OFTKAIAadapter
     *
     *      All deployed addresses are logged to the console for reference
     */
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
        oftkaiaadapter = new OFTKAIAadapter(KAIA_MOCK_WKAIA, address(elevatedminterburner), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_MOCK_WKAIA_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);
        oftwkaia = address(oftkaiaadapter);
    }

    // ========================================
    // INTERNAL FUNCTIONS - LayerZero Configuration
    // ========================================

    /**
     * @notice Configures send and receive libraries for both OFT adapters on the LayerZero endpoint
     * @dev Sets the following for both USDT and WKAIA OFT adapters:
     *      - Send library for the destination chain (eid0)
     *      - Receive library for the source chain with a grace period
     *
     *      The grace period determines how long until the new library becomes active.
     *      A value of 0 means the library is active immediately.
     */
    function _setLibraries() internal {
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oftusdt, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oftwkaia, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oftusdt, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oftwkaia, srcEid, receiveLib, gracePeriod);
    }

    /**
     * @notice Configures send parameters including DVNs and executor for cross-chain messaging
     * @dev Sets up the UlnConfig and ExecutorConfig for both destination chains (eid0 and eid1):
     *
     *      UlnConfig parameters:
     *      - confirmations: 15 block confirmations required before message processing
     *      - requiredDVNCount: 2 DVNs must verify the message
     *      - optionalDVNCount: Set to max (no optional DVNs used)
     *      - optionalDVNThreshold: 0 (not applicable when no optional DVNs)
     *      - requiredDVNs: Array containing dvn1 and dvn2
     *      - optionalDVNs: Empty array
     *
     *      ExecutorConfig parameters:
     *      - maxMessageSize: 10000 bytes maximum message size
     *      - executor: Address that will execute messages on the destination chain
     *
     *      Creates 4 configuration parameters:
     *      1. Executor config for eid0
     *      2. ULN config for eid0
     *      3. Executor config for eid1
     *      4. ULN config for eid1
     *
     *      Applies these configurations to both USDT and WKAIA OFT adapters
     */
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

    /**
     * @notice Configures receive parameters including DVN verification requirements
     * @dev Sets up the UlnConfig for receiving messages from both source chains (eid0 and eid1):
     *
     *      UlnConfig parameters:
     *      - confirmations: 15 block confirmations required before accepting a message
     *      - requiredDVNCount: 2 DVNs must verify the incoming message
     *      - optionalDVNCount: Set to max (no optional DVNs used)
     *      - optionalDVNThreshold: 0 (not applicable when no optional DVNs)
     *      - requiredDVNs: Array containing dvn1 and dvn2
     *      - optionalDVNs: Empty array
     *
     *      Creates 2 configuration parameters:
     *      1. Receive config for eid0
     *      2. Receive config for eid1
     *
     *      Applies these configurations to both USDT and WKAIA OFT adapters via the receive library
     */
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

    /**
     * @notice Establishes peer relationships between OFT adapters on different chains
     * @dev Sets up trusted peers for cross-chain communication:
     *      - BASE USDT OFT adapter is paired with KAIA USDT OFT adapter
     *      - BASE WKAIA OFT adapter is paired with KAIA WKAIA OFT adapter
     *
     *      The peer address is converted to bytes32 format as required by LayerZero.
     *
     *      Note: The commented-out lines would set peers in the opposite direction
     *      (from KAIA to BASE), but are currently disabled, suggesting this script
     *      is run from the BASE chain side only.
     */
    function _setPeers() internal {
        // MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_USDT_ADAPTER))));
        // MyOApp(KAIA_OFT_MOCK_WKAIA_ADAPTER).setPeer(BASE_EID, bytes32(uint256(uint160(BASE_OFT_MOCK_WKAIA_ADAPTER))));

        MyOApp(BASE_OFT_MOCK_USDT_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_USDT_ADAPTER))));
        MyOApp(BASE_OFT_MOCK_WKAIA_ADAPTER).setPeer(KAIA_EID, bytes32(uint256(uint160(KAIA_OFT_MOCK_WKAIA_ADAPTER))));
    }

    /**
     * @notice Sets enforced options for cross-chain message execution on both OFT adapters
     * @dev Configures gas limits for LayerZero message execution on destination chains:
     *
     *      - options1: 80,000 gas limit for eid0 (first destination chain)
     *      - options2: 100,000 gas limit for eid1 (second destination chain)
     *
     *      Creates an array of enforced options with:
     *      - eid: The destination chain endpoint ID
     *      - msgType: The message type (SEND = 1)
     *      - options: The encoded gas limit options
     *
     *      These enforced options ensure that cross-chain messages have sufficient gas
     *      to execute on the destination chain. The higher gas limit for eid1 suggests
     *      that operations on that chain may be more complex or gas-intensive.
     *
     *      Applies these options to both USDT and WKAIA OFT adapters on KAIA chain.
     */
    function _setEnforcedOFT() internal {
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: eid0, msgType: SEND, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: eid1, msgType: SEND, options: options2});

        MyOApp(KAIA_OFT_MOCK_USDT_ADAPTER).setEnforcedOptions(enforcedOptions);
        MyOApp(KAIA_OFT_MOCK_WKAIA_ADAPTER).setEnforcedOptions(enforcedOptions);
    }

    /**
     * @notice Registers the deployed OFT adapter addresses with the lending pool factory
     * @dev Associates each mock token with its corresponding OFT adapter in the factory:
     *      - KAIA_MOCK_USDT is mapped to the USDT OFT adapter address
     *      - KAIA_MOCK_WKAIA is mapped to the WKAIA OFT adapter address
     *
     *      This allows the lending pool factory to recognize and use these OFT adapters
     *      for cross-chain token operations within the Senja protocol.
     */
    function _setOFTAddress() internal {
        IFactory(KAIA_lendingPoolFactoryProxy).setOftAddress(KAIA_MOCK_USDT, oftusdt);
        IFactory(KAIA_lendingPoolFactoryProxy).setOftAddress(KAIA_MOCK_WKAIA, oftwkaia);
    }

    // ========================================
    // UTILITY FUNCTIONS
    // ========================================

    /**
     * @notice Converts a fixed-size array of 2 addresses to a dynamic array
     * @dev Helper function used to convert DVN addresses from fixed array to dynamic array
     *      format required by the UlnConfig struct
     * @param fixedArray A fixed-size array containing exactly 2 addresses
     * @return dynamicArray A dynamic array containing the same 2 addresses
     */
    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }
}

// RUN
// forge script DevSenja --broadcast -vvv
