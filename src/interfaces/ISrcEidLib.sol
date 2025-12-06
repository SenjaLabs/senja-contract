// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ISrcEidLib
 * @notice Interface for managing source endpoint ID (EID) information in LayerZero
 * @dev Stores decimal information for tokens on different chains identified by their EID
 */
interface ISrcEidLib {
    /**
     * @notice Struct containing source endpoint information
     * @param eid LayerZero endpoint ID for the source chain
     * @param decimals Number of decimals for the token on the source chain
     */
    struct SrcEidInfo {
        uint32 eid;
        uint8 decimals;
    }

    /**
     * @notice Returns the decimal places for a token on a specific endpoint
     * @param eid LayerZero endpoint ID
     * @return Number of decimals for the token on the specified endpoint
     */
    function srcDecimals(uint32 eid) external view returns (uint8);

    /**
     * @notice Sets the source endpoint information
     * @param srcEid Source LayerZero endpoint ID
     * @param decimals Number of decimals for the token on the source chain
     */
    function setSrcEidInfo(uint32 srcEid, uint8 decimals) external;
}
