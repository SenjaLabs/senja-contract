// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISrcEidLib} from "../interfaces/ISrcEidLib.sol";

contract SrcEidLib is Ownable {

    mapping(uint32 => uint8) public srcDecimals;

    constructor(ISrcEidLib.SrcEidInfo[] memory srcEidInfos, address _owner) Ownable(_owner) {
        for (uint256 i; i < srcEidInfos.length; i++) {
            srcDecimals[srcEidInfos[i].eid] = srcEidInfos[i].decimals;
        }
    }

    function setSrcEidInfo(uint32 srcEid, uint8 decimals) external onlyOwner {
        srcDecimals[srcEid] = decimals;
    }
}
