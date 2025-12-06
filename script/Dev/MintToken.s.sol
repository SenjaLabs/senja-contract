// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title IToken
/// @notice Interface for token contracts that support minting and operator management
/// @dev This interface provides the minimal functions needed for minting tokens and managing operators
interface IToken {
    /// @notice Mints new tokens to a specified address
    /// @dev Only authorized operators should be able to call this function
    /// @param _to The address that will receive the minted tokens
    /// @param _amount The amount of tokens to mint (in token's smallest unit)
    function mint(address _to, uint256 _amount) external;

    /// @notice Sets or removes an address as an operator
    /// @dev This function manages operator permissions for token operations
    /// @param _operator The address to grant or revoke operator status
    /// @param _isOperator True to grant operator status, false to revoke it
    function setOperator(address _operator, bool _isOperator) external;
}

/// @title MintToken
/// @notice Development script for minting tokens to a specified address
/// @dev This Forge script is used for testing and development purposes to mint tokens
///      Inherits from Script for Forge functionality and Helper for network constants
contract MintToken is Script, Helper {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address that will receive the minted tokens
    /// @dev Retrieved from the PUBLIC_KEY environment variable
    address public minter = vm.envAddress("PUBLIC_KEY");

    /// @notice The address of the token contract to mint from
    /// @dev Currently set to KAIA_MOCK_USDT from the Helper contract
    address public token = KAIA_MOCK_USDT;

    /// @notice The amount of tokens to mint (in human-readable units)
    /// @dev This value will be multiplied by the token's decimals before minting
    ///      For example: 100_000 USDT = 100_000 * 10^6 = 100,000,000,000 smallest units
    uint256 public amount = 100_000;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes the token minting script
    /// @dev This function performs the following steps:
    ///      1. Starts a broadcast using the private key from environment variables
    ///      2. Mints tokens to the minter address with proper decimal adjustment
    ///      3. Stops the broadcast and logs the minting operation
    ///      The commented-out lines can be used to:
    ///      - Create a fork of Kaia or Base mainnet for testing
    ///      - Set the operator status before minting if required
    function run() public {
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        // vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // IToken(token).setOperator(minter, true);
        IToken(token).mint(minter, amount * 10 ** IERC20Metadata(token).decimals());
        vm.stopBroadcast();
        console.log("Minted", amount, "tokens");
    }
}

// RUN
// forge script MintToken --broadcast -vvv
// forge script MintToken -vvv
