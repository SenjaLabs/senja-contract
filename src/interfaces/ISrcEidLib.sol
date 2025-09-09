// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISrcEidLib {
    struct SrcEidInfo {
        uint32 eid;
        uint8 decimals;
    }

    function srcDecimals(uint32 eid) external view returns (uint8);
    function setSrcEidInfo(uint32 srcEid, uint8 decimals) external;
}
