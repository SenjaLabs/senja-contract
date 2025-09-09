// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {OFTAdapter} from "../../src/layerzero/OFTAdapter.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Helper} from "./Helper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ProofOfWork is Script, Helper {
    using OptionsBuilder for bytes;

    address public oftAddress;
    address public TOKEN;
    address public minterBurner;
    uint256 public amount = 1_000;

    function setUp() public {
        // vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            oftAddress = BASE_OAPP;
            TOKEN = BASE_USDT;
            minterBurner = BASE_MINTER_BURNER;
        } else if (block.chainid == 8217) {
            oftAddress = KAIA_OAPP;
            TOKEN = KAIA_USDT;
            minterBurner = KAIA_MINTER_BURNER;
        }
    }

    function _sendParam(uint32 dstEid, bytes memory extraOptions) internal view returns (SendParam memory) {
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: addressToBytes32(vm.envAddress("PUBLIC_KEY")),
            amountLD: amount * 10 ** IERC20Metadata(TOKEN).decimals(), // src,
            minAmountLD: amount * 10 ** IERC20Metadata(TOKEN).decimals(), // src, // 0% slippage tolerance
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        return sendParam;
    }

    function run() public {
        _getUtils();
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        //** DESTINATION
        uint32 dstEid1 = BASE_EID; // dst
        uint32 dstEid2 = KAIA_EID; // dst

        //**************
        vm.startBroadcast(privateKey);
        OFTAdapter oft = OFTAdapter(oftAddress);
        // Build send parameters
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam1 = _sendParam(dstEid1, extraOptions);
        SendParam memory sendParam2 = _sendParam(dstEid2, extraOptions);

        // Get fee quote
        MessagingFee memory fee1 = oft.quoteSend(sendParam1, false);
        MessagingFee memory fee2 = oft.quoteSend(sendParam2, false);

        console.log(
            "total fee = ",
            fee1.nativeFee + fee2.nativeFee
        );

        console.log("TOKEN Balance before", IERC20(TOKEN).balanceOf(vm.envAddress("PUBLIC_KEY")));

        // Send tokens

        IERC20(TOKEN).approve(minterBurner, 6 * amount * 10 ** IERC20Metadata(TOKEN).decimals());
        oft.send{value: fee1.nativeFee}(sendParam1, fee1, msg.sender);
        oft.send{value: fee2.nativeFee}(sendParam2, fee2, msg.sender);

        console.log("TOKEN Balance after", IERC20(TOKEN).balanceOf(vm.envAddress("PUBLIC_KEY")));

        vm.stopBroadcast();
    }
}
// RUN
// forge script ProofOfWork --broadcast -vvv
