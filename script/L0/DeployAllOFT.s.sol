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

/**
 * @title DeployAllOFT
 * @notice Deployment script for deploying and configuring OFT (Omnichain Fungible Token) adapters across multiple chains
 * @dev This script handles the complete deployment and configuration of LayerZero OFT infrastructure including:
 *      - Deploying mock tokens or using existing tokens
 *      - Deploying ElevatedMinterBurner contracts
 *      - Deploying OFT adapters
 *      - Configuring LayerZero libraries (send and receive)
 *      - Setting up DVN (Decentralized Verifier Network) configurations
 *      - Configuring executor settings
 *      - Setting up peer connections (optional)
 *      - Configuring enforced options (optional)
 *      Supports KAIA mainnet (8217), BASE (8453), GLMR (1284), and KAIA testnet (1001)
 */
contract DeployAllOFT is Script, Helper {
    using OptionsBuilder for bytes;

    // ============================================
    // STATE VARIABLES - DEPLOYMENT CONFIGURATION
    // ============================================

    /// @notice The owner address for deployed contracts, loaded from environment variable
    address owner = vm.envAddress("PUBLIC_KEY");

    /// @notice The private key used for broadcasting transactions, loaded from environment variable
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    // ============================================
    // STATE VARIABLES - MOCK TOKENS
    // ============================================

    /// @notice Mock USDT token instance for testing purposes
    MOCKUSDT public mockUsdt;

    /// @notice Mock WKAIA token instance for testing purposes
    MOCKWKAIA public mockWkaia;

    /// @notice Mock WETH token instance for testing purposes
    MOCKWETH public mockWeth;

    /// @notice Generic mock token instance for flexible token deployment
    MOCKTOKEN public mockToken;

    /// @notice STOKEN (bridge token) instance for cross-chain token representation
    STOKEN public sToken;

    // ============================================
    // STATE VARIABLES - OFT CONTRACTS
    // ============================================

    /// @notice OFT adapter contract that wraps the underlying token for cross-chain transfers
    OFTadapter public oftadapter;

    /// @notice Elevated minter/burner contract with special permissions for OFT operations
    ElevatedMinterBurner public elevatedMinterBurner;

    // ============================================
    // STATE VARIABLES - token AND NETWORK CONFIG
    // ============================================

    /// @notice The address of the token to be bridged via OFT
    address public token;

    /// @notice LayerZero endpoint address for the current chain
    address endpoint;

    /// @notice Primary OApp (Omnichain Application) address, typically the OFT adapter
    address oapp;

    /// @notice Secondary OApp address for peer configuration
    address oapp2;

    /// @notice Send library address for LayerZero messaging
    address sendLib;

    /// @notice Receive library address for LayerZero messaging
    address receiveLib;

    /// @notice Source endpoint ID for the current chain
    uint32 srcEid;

    /// @notice Grace period for library upgrades (in seconds)
    uint32 gracePeriod;

    // ============================================
    // STATE VARIABLES - DVN AND EXECUTOR CONFIG
    // ============================================

    /// @notice First Decentralized Verifier Network address
    address dvn1;

    /// @notice Second Decentralized Verifier Network address
    address dvn2;

    /// @notice Executor address for LayerZero message execution
    address executor;

    // ============================================
    // STATE VARIABLES - EID AND TYPE CONSTANTS
    // ============================================

    /// @notice Shared decimals for token normalization across chains
    uint8 public sharedDecimals;

    /// @notice Endpoint ID for the source chain
    uint32 eid0;

    /// @notice Endpoint ID for the destination chain
    uint32 eid1;

    /// @notice Configuration type constant for executor settings
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;

    /// @notice Configuration type constant for ULN (Ultra Light Node) settings
    uint32 constant ULN_CONFIG_TYPE = 2;

    /// @notice Configuration type constant for receive settings
    uint32 constant RECEIVE_CONFIG_TYPE = 2;

    /// @notice Name of the current chain (e.g., "KAIA", "BASE", "GLMR")
    string chainName;

    /// @notice Flag indicating if the current chain is a destination chain for minting
    bool isDestination;

    // ============================================
    // MAIN EXECUTION FUNCTION
    // ============================================

    /**
     * @notice Main execution function that orchestrates the complete OFT deployment
     * @dev Executes the following steps:
     *      1. Creates and selects fork for KAIA mainnet
     *      2. Retrieves chain-specific utilities and configurations
     *      3. Deploys OFT adapter and related contracts
     *      4. Sets up LayerZero libraries (send and receive)
     *      5. Configures send and receive parameters
     *      Note: Steps 2 (setPeers and setEnforcedOptions) are commented out and should be
     *      executed separately after deployment on all chains
     */
    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(privateKey);
        _getUtils();
        // ******************************
        // *********** Step 1 ***********
        // ******************************
        _deployOft();
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

    // ============================================
    // INTERNAL FUNCTIONS - CONFIGURATION
    // ============================================

    /**
     * @notice Retrieves and sets chain-specific utilities and configuration parameters
     * @dev Configures the deployment based on the current chain ID:
     *      - KAIA mainnet (8217): Sets up KAIA-specific endpoints, libraries, DVNs, and executor
     *      - BASE (8453): Sets up BASE-specific endpoints, libraries, DVNs, and executor
     *      - GLMR (1284): Sets up Moonbeam-specific endpoints, libraries, DVNs, and executor
     *      - KAIA testnet (1001): Deploys mock token only for testing
     *      All configurations use the Helper contract's predefined constants
     */
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
            token = _deployMockToken("USD Tether", "USDT", 6); // **
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
            token = _deployMockToken("USD Tether", "USDT", 6); // **
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
            token = _deployMockToken("USD Tether", "USDT", 6); // **
            oapp; // **
            oapp2; // **
        }
        // TESTNET
        else if (block.chainid == 1001) {
            token = _deployMockToken("USD Tether", "USDT", 6);
        }
    }

    // ============================================
    // INTERNAL FUNCTIONS - token DEPLOYMENT
    // ============================================

    /**
     * @notice Deploys a mock ERC20 token for testing purposes
     * @dev Creates a new instance of MOCKTOKEN with the specified parameters
     * @param _name The full name of the token (e.g., "USD Tether")
     * @param _symbol The token symbol (e.g., "USDT")
     * @param _decimals The number of decimals for the token (e.g., 6 for USDT)
     * @return The address of the newly deployed mock token
     */
    function _deployMockToken(string memory _name, string memory _symbol, uint8 _decimals) internal returns (address) {
        mockToken = new MOCKTOKEN(_name, _symbol, _decimals);
        return address(mockToken);
    }

    /**
     * @notice Deploys a bridge token (STOKEN) for cross-chain representation
     * @dev Creates a new instance of STOKEN which can be minted/burned for cross-chain transfers
     * @param _name The full name of the bridge token
     * @param _symbol The token symbol for the bridge token
     * @param _decimals The number of decimals for the bridge token
     * @return The address of the newly deployed STOKEN
     */
    function _deployStoken(string memory _name, string memory _symbol, uint8 _decimals) internal returns (address) {
        sToken = new STOKEN(_name, _symbol, _decimals);
        return address(sToken);
    }

    // ============================================
    // INTERNAL FUNCTIONS - OFT DEPLOYMENT
    // ============================================

    /**
     * @notice Deploys and configures the OFT adapter and related contracts
     * @dev Performs the following operations:
     *      1. Deploys ElevatedMinterBurner with the token and owner
     *      2. Deploys OFTadapter with token, minter/burner, endpoint, owner, and decimals
     *      3. Sets the OFTadapter as an operator on the ElevatedMinterBurner
     *      4. Logs deployment addresses for verification and tracking
     *      5. If on a destination chain, grants operator role to ElevatedMinterBurner on the STOKEN
     * @dev The console logs include chain ID and token symbol for easy identification
     */
    function _deployOft() internal {
        elevatedMinterBurner = new ElevatedMinterBurner(token, owner);
        oftadapter = new OFTadapter(token, address(elevatedMinterBurner), endpoint, owner, _getDecimals(token));
        oapp = address(oftadapter);
        elevatedMinterBurner.setOperator(oapp, true);

        console.log(
            "address public %s_%s_ELEVATED_MINTER_BURNER = %s;",
            block.chainid,
            _getSymbol(token),
            address(elevatedMinterBurner)
        );
        console.log("address public %s_%s_OFT_ADAPTER = %s;", block.chainid, _getSymbol(token), address(oapp));

        if (isDestination) STOKEN(token).setOperator(address(elevatedMinterBurner), true);
    }

    // ============================================
    // INTERNAL FUNCTIONS - LAYERZERO CONFIGURATION
    // ============================================

    /**
     * @notice Configures LayerZero send and receive libraries for the OFT adapter
     * @dev Sets up the messaging libraries for both source and destination chains:
     *      - Configures send library for both eid0 (source) and eid1 (destination)
     *      - Configures receive library for the source endpoint with grace period
     *      This enables the OFT to send and receive cross-chain messages through LayerZero
     */
    function _setLibraries() internal {
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, eid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp, srcEid, receiveLib, gracePeriod);
    }

    /**
     * @notice Configures the send parameters for cross-chain messaging
     * @dev Sets up ULN (Ultra Light Node) and Executor configurations:
     *      - ULN Config: 15 confirmations, 2 required DVNs, no optional DVNs
     *      - Executor Config: 10000 max message size
     *      - Applies configuration to both eid0 and eid1 endpoints
     *      The configuration ensures security through multiple DVN verification and
     *      limits message size for gas optimization
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
        params[0] = SetConfigParam({eid: eid0, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[1] = SetConfigParam({eid: eid0, configType: ULN_CONFIG_TYPE, config: encodedUln});
        params[2] = SetConfigParam({eid: eid1, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[3] = SetConfigParam({eid: eid1, configType: ULN_CONFIG_TYPE, config: encodedUln});
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
    }

    /**
     * @notice Configures the receive parameters for cross-chain messaging
     * @dev Sets up ULN configuration for receiving messages:
     *      - ULN Config: 15 confirmations, 2 required DVNs, no optional DVNs
     *      - Applies configuration to both eid0 and eid1 endpoints
     *      The configuration mirrors the send config to ensure consistent security
     *      across both directions of cross-chain communication
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
        params[0] = SetConfigParam({eid: eid0, configType: RECEIVE_CONFIG_TYPE, config: encodedUln});
        params[1] = SetConfigParam({eid: eid1, configType: RECEIVE_CONFIG_TYPE, config: encodedUln});

        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
    }

    /**
     * @notice Sets up peer connections between OFT adapters on different chains
     * @dev Configures the trusted remote addresses for cross-chain communication:
     *      - Converts oapp and oapp2 addresses to bytes32 format
     *      - Sets peer for eid0 (source chain) and eid1 (destination chain)
     *      This function should be called after deploying OFT adapters on all chains
     *      to establish the trusted connection between them
     */
    function _setPeers() internal {
        bytes32 oftPeer = bytes32(uint256(uint160(address(oapp))));
        bytes32 oftPeer2 = bytes32(uint256(uint160(address(oapp2))));
        OFTadapter(oapp).setPeer(eid0, oftPeer);
        OFTadapter(oapp).setPeer(eid1, oftPeer2);
    }

    /**
     * @notice Configures enforced execution options for cross-chain messages
     * @dev Sets up gas limits for message execution on destination chains:
     *      - eid0: 80000 gas limit for lzReceive execution
     *      - eid1: 100000 gas limit for lzReceive execution
     *      - SEND message type (1) is configured with these options
     *      Enforced options ensure sufficient gas is provided for reliable message delivery
     *      and execution on the destination chain
     */
    function _setEnforcedOptions() internal {
        uint16 send = 1;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: eid0, msgType: send, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: eid1, msgType: send, options: options2});

        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
    }

    // ============================================
    // INTERNAL FUNCTIONS - UTILITY HELPERS
    // ============================================

    /**
     * @notice Converts a fixed-size array to a dynamic array
     * @dev Helper function for converting address[2] to address[] for LayerZero configurations
     * @param fixedArray A fixed-size array of 2 addresses (typically DVN addresses)
     * @return dynamicArray A dynamic array containing the same addresses
     */
    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }

    /**
     * @notice Retrieves the symbol of an ERC20 token
     * @dev Calls the symbol() function on the ERC20Metadata interface
     * @param _token The address of the token to query
     * @return The token symbol as a string (e.g., "USDT", "WETH")
     */
    function _getSymbol(address _token) internal view returns (string memory) {
        return IERC20Metadata(_token).symbol();
    }

    /**
     * @notice Retrieves the number of decimals for an ERC20 token
     * @dev Calls the decimals() function on the ERC20Metadata interface
     * @param _token The address of the token to query
     * @return The number of decimals for the token (e.g., 6 for USDT, 18 for WETH)
     */
    function _getDecimals(address _token) internal view returns (uint8) {
        return IERC20Metadata(_token).decimals();
    }
}
// forge script DeployAllOFT --broadcast -vvv --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
// forge script DeployAllOFT --broadcast -vvv
// forge script DeployAllOFT -vvv
