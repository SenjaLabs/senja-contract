// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {OFTadapter} from "../../src/layerzero/OFTadapter.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Helper} from "../DevTools/Helper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title DevSendOFT
/// @notice Development script for sending tokens cross-chain using LayerZero OFT (Omnichain Fungible Token) adapter
/// @dev This script is intended for development and testing purposes. It demonstrates how to send tokens
///      from a source chain to a destination chain using the LayerZero OFT adapter pattern.
///      The script handles token approval, fee calculation, and cross-chain message execution.
contract DevSendOFT is Script, Helper {
    using OptionsBuilder for bytes;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The recipient address for the cross-chain token transfer
    /// @dev Retrieved from the PUBLIC_KEY environment variable
    address toAddress = vm.envAddress("PUBLIC_KEY");

    // *********FILL THIS*********
    /// @notice Address of the OFT adapter contract on the source chain
    /// @dev This is the contract that wraps/adapts the source token for cross-chain transfer
    address oftAddress = KAIA_OFT_MOCK_USDT_ADAPTER; // src

    /// @notice Address of the elevated minter/burner contract for the token
    /// @dev Used for privileged minting and burning operations during cross-chain transfers
    address minterBurner = KAIA_MOCK_USDT_ELEVATED_MINTER_BURNER;

    /// @notice Address of the source token contract on the origin chain
    /// @dev This is the actual ERC20 token being sent cross-chain
    address TOKEN = KAIA_MOCK_USDT;

    /// @notice The base amount of tokens to send (in token's native decimals)
    /// @dev Set to 1e6 for USDT (6 decimals)
    uint256 amount = 1e6; // amount to send

    /// @notice The actual amount of tokens to send in the cross-chain transaction
    /// @dev Initialized to match the amount variable
    uint256 tokensToSend = amount; // src

    /// @notice Private key for signing the transaction
    /// @dev Retrieved from the PRIVATE_KEY environment variable - handle with care
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    //*******
    //** DESTINATION

    /// @notice LayerZero endpoint ID for the destination chain
    /// @dev BASE_EID represents Base chain as the destination
    uint32 dstEid = BASE_EID; // dst
    //*******
    //***************************

    // ============================================
    // SETUP FUNCTION
    // ============================================

    /// @notice Sets up the testing environment by forking the Kaia mainnet
    /// @dev Creates and selects a fork of the Kaia mainnet to simulate the source chain environment.
    ///      This allows testing cross-chain functionality in a controlled environment.
    function setUp() public {
        // base
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        // optimism
        // hyperliquid
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @notice Converts an Ethereum address to a bytes32 representation
    /// @dev This conversion is necessary for LayerZero cross-chain messaging, which uses bytes32
    ///      to represent addresses across different blockchain architectures. The address is first
    ///      cast to uint160, then to uint256, and finally to bytes32 with left-padding of zeros.
    /// @param _addr The Ethereum address to convert
    /// @return The bytes32 representation of the address
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // ============================================
    // MAIN EXECUTION FUNCTION
    // ============================================

    /// @notice Main execution function that orchestrates the cross-chain token transfer
    /// @dev This function performs the following steps:
    ///      1. Initializes the OFT adapter contract instance
    ///      2. Builds LayerZero execution options with gas limits
    ///      3. Constructs the SendParam struct with transfer details
    ///      4. Quotes the messaging fee for the cross-chain transaction
    ///      5. Approves the OFT adapter to spend tokens
    ///      6. Executes the cross-chain send operation
    ///      7. Logs balances before and after for verification
    ///      All operations are broadcast using the configured private key.
    ///      The extraOptions specify 65000 gas for the lzReceive execution on the destination chain.
    function run() external {
        vm.startBroadcast(privateKey);
        OFTadapter oft = OFTadapter(oftAddress);
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: addressToBytes32(toAddress),
            amountLD: tokensToSend,
            minAmountLD: tokensToSend,
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = oft.quoteSend(sendParam, false);
        console.log("Sending tokens...");
        console.log("Fee amount:", fee.nativeFee);
        console.log("TOKEN Balance before", IERC20(TOKEN).balanceOf(toAddress));
        IERC20(TOKEN).approve(oftAddress, tokensToSend);
        oft.send{value: fee.nativeFee}(sendParam, fee, toAddress);
        console.log("TOKEN Balance after", IERC20(TOKEN).balanceOf(toAddress));

        vm.stopBroadcast();
    }
}

// RUN
// forge script DevSendOFT --broadcast -vvv
