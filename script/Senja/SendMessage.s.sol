// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../DevTools/Helper.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTAdapter.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OAppSupplyLiquidityUSDT} from "../../src/layerzero/messages/OAppSupplyLiquidityUSDT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OAppAdapter} from "../../src/layerzero/messages/OAppAdapter.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";

contract SendMessage is Script, Helper {
    using OptionsBuilder for bytes;

    address owner = vm.envAddress("PUBLIC_KEY");
    OAppSupplyLiquidityUSDT public oappSupplyLiquidityUSDT;
    address token;
    address KAIA_lendingPool = 0x3571b96b1418910FD03831d35730172e4d011B06;
    uint256 amount = 100e6;
    address oappAdapter;

    function run() external {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _getUtils();
        _sendMessageSupplyLiquidity();
        // _checkTokenOFT();
        vm.stopBroadcast();
    }

    function _sendMessageSupplyLiquidity() internal {
        // MessagingFee memory feeMessage = OAppSupplyLiquidityUSDT(BASE_oappSupplyLiquidityUSDT).quoteSendString(
        //     KAIA_EID, KAIA_lendingPool, owner, token, amount, "", false
        // );

        // bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        // SendParam memory sendParam = SendParam({
        //     dstEid: KAIA_EID,
        //     to: _addressToBytes32(address(KAIA_oappSupplyLiquidityUSDT)), //OAPP DST
        //     amountLD: amount,
        //     minAmountLD: amount, // 0% slippage tolerance
        //     extraOptions: extraOptions,
        //     composeMsg: "",
        //     oftCmd: ""
        // });
        // MessagingFee memory feeBridge = OFTUSDTadapter(BASE_OFT_USDTK_ADAPTER).quoteSend(sendParam, false);
        // console.log("feeMessage", feeMessage.nativeFee);
        // console.log("feeBridge", feeBridge.nativeFee);
        // console.log("mix fee", feeMessage.nativeFee + feeBridge.nativeFee);
        // IERC20(token).approve(address(BASE_oappSupplyLiquidityUSDT), amount);
        // OAppSupplyLiquidityUSDT(BASE_oappSupplyLiquidityUSDT).sendString{
        //     value: feeMessage.nativeFee + feeBridge.nativeFee
        // }(KAIA_EID, KAIA_lendingPool, owner, KAIA_MOCK_USDT, KAIA_oappSupplyLiquidityUSDT, amount, 0, "");

        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: KAIA_EID,
            to: _addressToBytes32(address(KAIA_oappSupplyLiquidityUSDT)), //OAPP DST
            amountLD: amount,
            minAmountLD: amount, // 0% slippage tolerance
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory feeBridge = OFTUSDTadapter(BASE_OFT_MOCK_USDT_ADAPTER).quoteSend(sendParam, false);

        MessagingFee memory feeMessage = OAppSupplyLiquidityUSDT(BASE_oappSupplyLiquidityUSDT).quoteSendString(
            KAIA_EID, KAIA_lendingPool, owner, KAIA_MOCK_USDT, amount, "", false
        );

        IERC20(BASE_MOCK_USDT).approve(oappAdapter, amount);
        OAppAdapter(oappAdapter).sendBridge{value: feeBridge.nativeFee + feeMessage.nativeFee}(
            address(BASE_oappSupplyLiquidityUSDT),
            BASE_OFT_MOCK_USDT_ADAPTER,
            KAIA_lendingPool,
            BASE_MOCK_USDT,
            KAIA_MOCK_USDT,
            address(BASE_oappSupplyLiquidityUSDT),
            KAIA_EID,
            amount,
            feeBridge.nativeFee,
            feeMessage.nativeFee
        );

        console.log("SupplyLiquidityCrosschain");
    }

    function _checkTokenOFT() internal view {
        if (block.chainid == 8453) {
            console.log("tokenOFT", OFTUSDTadapter(BASE_OFT_USDTK_ADAPTER).tokenOFT());
            console.log("elevated", OFTUSDTadapter(BASE_OFT_USDTK_ADAPTER).elevatedMinterBurner());
            console.log("tokenOFT", OFTUSDTadapter(BASE_OFT_MOCK_USDT_ADAPTER).tokenOFT());
            console.log("elevated", OFTUSDTadapter(BASE_OFT_MOCK_USDT_ADAPTER).elevatedMinterBurner());
        } else if (block.chainid == 8217) {
            console.log("tokenOFT", OFTUSDTadapter(KAIA_OFT_MOCK_USDT_ADAPTER).tokenOFT());
            console.log("elevated", OFTUSDTadapter(KAIA_OFT_MOCK_USDT_ADAPTER).elevatedMinterBurner());
            console.log(
                "elevated operator",
                ElevatedMinterBurner(KAIA_MOCK_USDT_ELEVATED_MINTER_BURNER).operators(KAIA_OFT_MOCK_USDT_ADAPTER)
            );
        }
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            token = BASE_USDTK;
            oappAdapter = BASE_oappAdapter;
        } else if (block.chainid == 8217) {
            token = KAIA_MOCK_USDT;
        }
    }

    function _addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }
}

// RUN
//  forge script SendMessage --broadcast -vvv
//  forge script SendMessage -vvv
