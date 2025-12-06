// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {IWrappedNative} from "../../src/interfaces/IWrappedNative.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ConvertToWrappedToken
 * @notice Forge script for converting native KAIA tokens to wrapped KAIA (WKAIA) tokens
 * @dev This script demonstrates the process of depositing native tokens into a wrapped token contract
 *      on the Kaia mainnet. It uses Foundry's script functionality to execute on-chain transactions.
 *      The script connects to Kaia mainnet, deposits 1 KAIA token, and logs the balance changes.
 */
contract ConvertToWrappedToken is Script, Helper {
    /**
     * @notice Entry point for the script execution
     * @dev Calls the deployKAIA function to perform the token wrapping operation.
     *      This function is automatically called when the script is executed via forge script command.
     */
    function run() public {
        deployKAIA();
    }

    /**
     * @notice Converts native KAIA tokens to wrapped KAIA tokens on Kaia mainnet
     * @dev Performs the following operations:
     *      1. Creates and selects a fork of Kaia mainnet using the configured RPC URL
     *      2. Starts broadcasting transactions using the private key from environment variables
     *      3. Logs the native token balance and WKAIA token balance before deposit
     *      4. Deposits 1 KAIA (1e18 wei) into the WKAIA contract to receive wrapped tokens
     *      5. Logs the balances after deposit for verification
     *      6. Stops the transaction broadcast
     *
     *      The KAIA_WKAIA address is inherited from the Helper contract and points to the
     *      wrapped KAIA token contract on Kaia mainnet.
     *
     *      Environment variables required:
     *      - PRIVATE_KEY: The private key used to sign and broadcast the transaction
     *      - PUBLIC_KEY: The address whose balances are being logged and modified
     *
     *      Security considerations:
     *      - Ensure PRIVATE_KEY is kept secure and not exposed in logs or version control
     *      - The script deposits exactly 1 KAIA (hardcoded as 1e18 wei)
     *      - Verify sufficient native token balance exists before execution
     */
    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        console.log("balance before deposit: ", vm.envAddress("PUBLIC_KEY"));
        console.log("balance token before deposit: ", IERC20(KAIA_WKAIA).balanceOf(vm.envAddress("PUBLIC_KEY")));
        IWrappedNative(KAIA_WKAIA).deposit{value: 1e18}();
        console.log("balance after deposit: ", vm.envAddress("PUBLIC_KEY"));
        console.log("balance token after deposit: ", IERC20(KAIA_WKAIA).balanceOf(vm.envAddress("PUBLIC_KEY")));
        vm.stopBroadcast();
    }
}

// RUN
// forge script ConvertToWrappedToken --broadcast -vvv
