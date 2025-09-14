// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Helper} from "../L0/Helper.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IToken {
    function mint(address _to, uint256 _amount) external;
}

contract MintToken is Script, Helper {
    address public minter = 0x6D9DAE901fbA6d51A37C57b1619DfF67A6e39eB3;
    address public token = 0xCEb5c8903060197e46Ab5ea5087b9F99CBc8da49;
    uint256 public amount = 100_000;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        IToken(token).mint(minter, amount * 10 ** IERC20Metadata(token).decimals());
        vm.stopBroadcast();
    }
}

// RUN
// forge script MintToken --broadcast -vvv
