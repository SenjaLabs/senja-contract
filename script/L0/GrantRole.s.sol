// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {sUSDT} from "../../src/BridgeToken/sUSDT.sol";
import {sWKAIA} from "../../src/BridgeToken/sWKAIA.sol";
import {sWBTC} from "../../src/BridgeToken/sWBTC.sol";
import {sWETH} from "../../src/BridgeToken/sWETH.sol";

/**
 * @title GrantRole
 * @notice Deployment script for granting operator roles to elevated minter/burner contracts
 * @dev This script configures operator permissions for bridge tokens on the Base network.
 * It grants operator status to the elevated minter/burner contracts for each token type,
 * enabling them to mint and burn tokens as needed for cross-chain operations.
 *
 * Security Considerations:
 * - Uses private key from environment variables
 * - Only executes on Base mainnet (chain ID 8453)
 * - Sets operators for critical bridge token contracts
 * - Each token has its own dedicated elevated minter/burner contract
 */
contract GrantRole is Script, Helper {
    // ================================================================
    // STATE VARIABLES
    // ================================================================

    /// @notice Address of the sUSDT bridge token contract
    address SUSDT;

    /// @notice Address of the sWKAIA bridge token contract
    address SWKAIA;

    /// @notice Address of the sWBTC bridge token contract
    address SWBTC;

    /// @notice Address of the sWETH bridge token contract
    address SWETH;

    /// @notice Address of the elevated minter/burner contract for sUSDT
    address SUSDT_ELEVATED_MINTER_BURNER;

    /// @notice Address of the elevated minter/burner contract for sWKAIA
    address SWKAIA_ELEVATED_MINTER_BURNER;

    /// @notice Address of the elevated minter/burner contract for sWBTC
    address SWBTC_ELEVATED_MINTER_BURNER;

    /// @notice Address of the elevated minter/burner contract for sWETH
    address SWETH_ELEVATED_MINTER_BURNER;

    // ================================================================
    // MAIN FUNCTIONS
    // ================================================================

    /**
     * @notice Main execution function that grants operator roles to all elevated minter/burner contracts
     * @dev This function performs the following operations:
     * 1. Creates and selects a fork of Base mainnet
     * 2. Starts broadcasting transactions using the private key from environment
     * 3. Sets operator status to true for each elevated minter/burner contract
     * 4. Logs confirmation for each operation
     *
     * The operator role grants permission to mint and burn tokens, which is essential
     * for cross-chain bridge operations.
     *
     * Requirements:
     * - Must be executed with a valid private key in PRIVATE_KEY environment variable
     * - RPC URL for base_mainnet must be configured
     * - All token and elevated minter/burner addresses must be properly initialized via _getUtils()
     */
    function run() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        sUSDT(SUSDT).setOperator(SUSDT_ELEVATED_MINTER_BURNER, true);
        console.log("sUSDT operator set");
        sWKAIA(SWKAIA).setOperator(SWKAIA_ELEVATED_MINTER_BURNER, true);
        console.log("sWKAIA operator set");
        sWBTC(SWBTC).setOperator(SWBTC_ELEVATED_MINTER_BURNER, true);
        console.log("sWBTC operator set");
        sWETH(SWETH).setOperator(SWETH_ELEVATED_MINTER_BURNER, true);
        console.log("sWETH operator set");
        vm.stopBroadcast();
    }

    // ================================================================
    // INTERNAL FUNCTIONS
    // ================================================================

    /**
     * @notice Internal function to initialize contract addresses based on the current chain ID
     * @dev Populates all state variables with the appropriate addresses for the deployed contracts.
     * Currently supports Base mainnet (chain ID 8453). The addresses are inherited from the
     * Helper contract which contains deployment configurations.
     *
     * Chain-specific behavior:
     * - Chain ID 8453 (Base mainnet): Initializes all token and elevated minter/burner addresses
     *
     * Note: This function should be called before executing the main script logic to ensure
     * all addresses are properly set for the target network.
     */
    function _getUtils() internal {
        if (block.chainid == 8453) {
            SUSDT = BASE_SUSDT;
            SWKAIA = BASE_SWKAIA;
            SWBTC = BASE_SWBTC;
            SWETH = BASE_SWETH;
            SUSDT_ELEVATED_MINTER_BURNER = BASE_SUSDT_ELEVATED_MINTER_BURNER;
            SWKAIA_ELEVATED_MINTER_BURNER = BASE_SWKAIA_ELEVATED_MINTER_BURNER;
            SWBTC_ELEVATED_MINTER_BURNER = BASE_SWBTC_ELEVATED_MINTER_BURNER;
            SWETH_ELEVATED_MINTER_BURNER = BASE_SWETH_ELEVATED_MINTER_BURNER;
        }
    }
}

// RUN
// forge script GrantRole --broadcast -vvv
