// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LendingPool} from "../../src/LendingPool.sol";

/**
 * @title CheckBalance
 * @notice Development script for checking token balances and withdrawing liquidity from the lending pool
 * @dev This script is intended for development and testing purposes on Kaia mainnet
 * It performs balance checks on the USDT OFT adapter and executes a liquidity withdrawal
 * WARNING: This script uses a hardcoded lending pool address and should be updated for production use
 */
contract CheckBalance is Script, Helper {
    //////////////////////////////////////////////////////////////////////////////
    //                              EXTERNAL FUNCTIONS                          //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Main execution function that checks balances and withdraws liquidity
     * @dev This function performs the following operations:
     * 1. Creates a fork of Kaia mainnet for testing
     * 2. Starts broadcasting transactions using the private key from environment variables
     * 3. Logs the USDT balance of the OFT adapter contract
     * 4. Withdraws 1 USDT (1e6 wei) from the hardcoded lending pool
     * 5. Stops broadcasting transactions
     *
     * Security considerations:
     * - Uses PRIVATE_KEY from environment variables - ensure this is kept secure
     * - Hardcoded lending pool address should be verified before execution
     * - Withdraws a fixed amount (1e6) - consider making this configurable
     *
     * Usage: forge script CheckBalance --broadcast -vvv
     */
    function run() external {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        console.log(
            "balance of KAIA_OFT_MOCK_USDT_ADAPTER", IERC20(KAIA_MOCK_USDT).balanceOf(KAIA_OFT_MOCK_USDT_ADAPTER)
        );
        LendingPool(payable(address(0x483f98e04C6AeCB40563B443Aa4e8C8d7662cc0F))).withdrawLiquidity(1e6);
        vm.stopBroadcast();
    }
}

// RUN
// forge script CheckBalance --broadcast -vvv
