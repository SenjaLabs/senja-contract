// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Helper} from "../DevTools/Helper.sol";

/**
 * @title SetLibraries
 * @notice Foundry script for configuring LayerZero send and receive libraries for cross-chain OFT adapters
 * @dev This script sets up the messaging libraries required for LayerZero V2 cross-chain communication
 *      between BASE and KAIA networks. It configures both send libraries (for outbound messages) and
 *      receive libraries (for inbound messages) for each OFT adapter contract on both chains.
 *
 *      The script performs the following operations:
 *      1. Configures BASE network OFT adapters to communicate with KAIA
 *      2. Configures KAIA network OFT adapters to communicate with BASE
 *      3. Sets send libraries for outbound cross-chain messages
 *      4. Sets receive libraries with grace periods for inbound messages
 *
 *      Security considerations:
 *      - Uses private key from environment variable PRIVATE_KEY
 *      - Executes transactions on mainnet networks (BASE and KAIA)
 *      - Requires proper LayerZero endpoint and library addresses from Helper contract
 */
contract SetLibraries is Script, Helper {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Destination endpoint ID for BASE network
    /// @dev Used when configuring KAIA adapters to send messages to BASE
    uint32 dstEid0 = BASE_EID;

    /// @notice Destination endpoint ID for KAIA network
    /// @dev Used when configuring BASE adapters to send messages to KAIA
    uint32 dstEid1 = KAIA_EID;

    /// @notice LayerZero endpoint address for the current network
    /// @dev Populated by _getUtils() based on the current chain ID
    address endpoint;

    /// @notice OApp (Omnichain Application) contract address
    /// @dev Currently unused but reserved for future functionality
    address oapp;

    /// @notice Send library address for outbound messages
    /// @dev Populated by _getUtils() based on the current chain ID
    address sendLib;

    /// @notice Receive library address for inbound messages
    /// @dev Populated by _getUtils() based on the current chain ID
    address receiveLib;

    /// @notice Source endpoint ID for the current network
    /// @dev Populated by _getUtils() based on the current chain ID
    uint32 srcEid;

    /// @notice Grace period for library upgrades in seconds
    /// @dev Currently set to 0, meaning immediate library activation
    uint32 gracePeriod;

    // ============================================
    // MAIN EXECUTION FUNCTION
    // ============================================

    /**
     * @notice Main entry point for the script execution
     * @dev Sequentially configures libraries for BASE and KAIA networks
     *      Currently configured for BASE and KAIA only. Optimism and HyperEVM
     *      configurations are commented out for future implementation.
     */
    function run() external {
        deployBase();
        deployKaia();
        // optimism
        // hyperevm
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /**
     * @notice Retrieves network-specific configuration based on the current chain ID
     * @dev Populates state variables with appropriate values for the current network
     *      Supports BASE (chainid: 8453) and KAIA (chainid: 8217) networks
     *
     *      Sets the following variables:
     *      - endpoint: LayerZero endpoint contract address
     *      - sendLib: Send library address for the network
     *      - receiveLib: Receive library address for the network
     *      - srcEid: Source endpoint ID for the network
     *      - gracePeriod: Library upgrade grace period (currently 0)
     *
     *      Security note: Relies on Helper contract constants for addresses
     */
    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            sendLib = KAIA_SEND_LIB;
            receiveLib = KAIA_RECEIVE_LIB;
            srcEid = KAIA_EID;
            gracePeriod = uint32(0);
        }
    }

    // ============================================
    // DEPLOYMENT FUNCTIONS
    // ============================================

    /**
     * @notice Configures LayerZero libraries for BASE network OFT adapters
     * @dev Performs the following operations:
     *      1. Switches to BASE mainnet fork
     *      2. Starts broadcast with private key from environment
     *      3. Loads BASE network configuration
     *      4. Sets send libraries for 4 OFT adapters (sUSDT, sWKAIA, sWBTC, sWETH)
     *      5. Sets receive libraries for the same adapters with grace period
     *
     *      OFT Adapters configured:
     *      - BASE_OFT_SUSDT_ADAPTER: Synthetic USDT adapter
     *      - BASE_OFT_SWKAIA_ADAPTER: Synthetic WKAIA adapter
     *      - BASE_OFT_SWBTC_ADAPTER: Synthetic WBTC adapter
     *      - BASE_OFT_SWETH_ADAPTER: Synthetic WETH adapter
     *
     *      All adapters are configured to communicate with KAIA network (dstEid1)
     *
     *      Security considerations:
     *      - Requires PRIVATE_KEY environment variable
     *      - Executes on BASE mainnet
     *      - Sets critical messaging infrastructure
     */
    function deployBase() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();

        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_SUSDT_ADAPTER, dstEid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_SWKAIA_ADAPTER, dstEid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_SWBTC_ADAPTER, dstEid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(BASE_OFT_SWETH_ADAPTER, dstEid1, sendLib);

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_SUSDT_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_SWKAIA_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_SWBTC_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(BASE_OFT_SWETH_ADAPTER, srcEid, receiveLib, gracePeriod);

        vm.stopBroadcast();
    }

    /**
     * @notice Configures LayerZero libraries for KAIA network OFT adapters
     * @dev Performs the following operations:
     *      1. Switches to KAIA mainnet fork
     *      2. Starts broadcast with private key from environment
     *      3. Loads KAIA network configuration
     *      4. Sets send libraries for 5 OFT adapters (USDT, USDT Stargate, WKAIA, WBTC, WETH)
     *      5. Sets receive libraries for the same adapters with grace period
     *
     *      OFT Adapters configured:
     *      - KAIA_OFT_USDT_ADAPTER: Native USDT adapter
     *      - KAIA_OFT_USDT_STARGATE_ADAPTER: USDT adapter integrated with Stargate
     *      - KAIA_OFT_WKAIA_ADAPTER: Wrapped KAIA adapter
     *      - KAIA_OFT_WBTC_ADAPTER: Wrapped BTC adapter
     *      - KAIA_OFT_WETH_ADAPTER: Wrapped ETH adapter
     *
     *      All adapters are configured to communicate with BASE network (dstEid0)
     *
     *      Security considerations:
     *      - Requires PRIVATE_KEY environment variable
     *      - Executes on KAIA mainnet
     *      - Sets critical messaging infrastructure
     *      - Note: KAIA has 5 adapters vs BASE's 4 due to dual USDT implementations
     */
    function deployKaia() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();

        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_USDT_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_USDT_STARGATE_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_WKAIA_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_WBTC_ADAPTER, dstEid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(KAIA_OFT_WETH_ADAPTER, dstEid0, sendLib);

        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_USDT_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint)
            .setReceiveLibrary(KAIA_OFT_USDT_STARGATE_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_WKAIA_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_WBTC_ADAPTER, srcEid, receiveLib, gracePeriod);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(KAIA_OFT_WETH_ADAPTER, srcEid, receiveLib, gracePeriod);

        vm.stopBroadcast();
    }
}
// RUN
// forge script SetLibraries --broadcast -vvv
// forge script SetLibraries -vvv
