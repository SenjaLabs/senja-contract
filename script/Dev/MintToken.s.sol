// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IToken {
    function mint(address _to, uint256 _amount) external;
}

contract MintToken is Script, Helper {
    address public minter = vm.envAddress("PUBLIC_KEY");
    address public token = KAIA_MOCK_USDT;
    uint256 public amount = 100_000e6;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        IToken(token).mint(minter, amount * 10 ** IERC20Metadata(token).decimals());
        vm.stopBroadcast();
        console.log("Minted", amount, "tokens");
    }
}

// RUN
// forge script MintToken --broadcast -vvv
