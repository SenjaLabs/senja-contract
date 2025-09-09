// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

contract Helper {
    // ***** MAINNET *****
    address public BASE_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address public KAIA_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    address public BASE_SEND_LIB = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
    address public KAIA_SEND_LIB = 0x9714Ccf1dedeF14BaB5013625DB92746C1358cb4;

    address public BASE_RECEIVE_LIB = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
    address public KAIA_RECEIVE_LIB = 0x937AbA873827BF883CeD83CA557697427eAA46Ee;

    uint32 public BASE_EID = 30184;
    uint32 public KAIA_EID = 30150;

    address public BASE_DVN1 = 0x554833698Ae0FB22ECC90B01222903fD62CA4B47; // Canary
    address public BASE_DVN2 = 0xa7b5189bcA84Cd304D8553977c7C614329750d99; // Horizen
    address public BASE_DVN3 = 0x9e059a54699a285714207b43B055483E78FAac25; // LayerZeroLabs

    address public KAIA_DVN1 = 0x1154d04d07AEe26ff2C200Bd373eb76a7e5694d6; // Canary
    address public KAIA_DVN2 = 0xaCDe1f22EEAb249d3ca6Ba8805C8fEe9f52a16e7; // Horizen
    address public KAIA_DVN3 = 0xc80233AD8251E668BecbC3B0415707fC7075501e; // LayerZeroLabs

    address public BASE_EXECUTOR = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
    address public KAIA_EXECUTOR = 0xe149187a987F129FD3d397ED04a60b0b89D1669f;

    // ** SELF DEPLOYED Mainnet **

    address public BASE_USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address public KAIA_USDT = 0xd077A400968890Eacc75cdc901F0356c943e4fDb;
    address public BASE_USDTk;
    address public KAIA_USDTk;

    address public BASE_SRC_EID_LIB;
    address public BASE_OAPP;
    address public BASE_MINTER_BURNER;
    address public ARB_SRC_EID_LIB;
    address public ARB_OAPP;
    address public ARB_MINTER_BURNER;
    address public POL_SRC_EID_LIB;
    address public POL_OAPP;
    address public POL_MINTER_BURNER;
    address public BSC_SRC_EID_LIB;
    address public BSC_OAPP;
    address public BSC_MINTER_BURNER;
    address public KAIA_SRC_EID_LIB;
    address public KAIA_OAPP;
    address public KAIA_MINTER_BURNER;
    address public GNOSIS_SRC_EID_LIB;
    address public GNOSIS_OAPP;
    address public GNOSIS_MINTER_BURNER;
    // *******************

    // forge verify-contract --verifier-url https://mainnet-api.kaiascan.io/forge-verify-flatten \
    // --chain-id 8217 \
    // 0x583C963CB88FD42409021039B692646617F77b63 src/MyMintBurnOFTAdapterDecimal2.sol:MyMintBurnOFTAdapterDecimal2 --retries 1

    // forge verify-contract --verifier-url https://mainnet-api.kaiascan.io/forge-verify-flatten \
    // --chain-id 8217 --compiler-version 0.8.28 \
    // 0x583C963CB88FD42409021039B692646617F77b63 MyMintBurnOFTAdapterDecimal2Flattened.sol:MyMintBurnOFTAdapterDecimal2 --retries 1
    // *******************
}
