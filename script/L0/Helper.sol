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

    address public KAIA_USDT = 0xd077A400968890Eacc75cdc901F0356c943e4fDb;
    address public KAIA_USDT_STARGATE = 0x9025095263d1E548dc890A7589A4C78038aC40ab; // stargate
    address public KAIA_KAIA = address(1);
    address public KAIA_WKAIA = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;
    address public KAIA_WETH = 0x98A8345bB9D3DDa9D808Ca1c9142a28F6b0430E1;
    address public KAIA_WBTC = 0x981846bE8d2d697f4dfeF6689a161A25FfbAb8F9;

    address public BASE_USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
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

    address public KAIA_OFT_USDT_ADAPTER = 0xdF05e9AbF64dA281B3cBd8aC3581022eC4841FB2;
    address public KAIA_OFT_USDT_STARGATE_ADAPTER = 0x04C37dc1b538E00b31e6bc883E16d97cD7937a10;
    address public KAIA_OFT_WKAIA_ADAPTER = 0x15858A57854BBf0DF60A737811d50e1Ee785f9bc;
    address public KAIA_OFT_WBTC_ADAPTER = 0x4Ba8D8083e7F3652CCB084C32652e68566E9Ef23;
    address public KAIA_OFT_WETH_ADAPTER = 0x007F735Fd070DeD4B0B58D430c392Ff0190eC20F;

    address public BASE_USDTK = 0xc3be8ab4CA0cefE3119A765b324bBDF54a16A65b;
    address public BASE_USDTK_ELEVATED_MINTER_BURNER = 0xE2e025Ff8a8adB2561e3C631B5a03842b9A1Ae88;
    address public BASE_OFT_USDTK_ADAPTER = 0x5E6AAd48fB0a23E9540A5EAFfb87846E8ef04C42;

    address public BASE_KAIAK = 0x46dA9F76c20a752132dDaefD2B14870e0A152D71;
    address public BASE_KAIAK_ELEVATED_MINTER_BURNER = 0xC72f2eb4A97F19ecD0C10b5201676a10B6D8bB67;
    address public BASE_OFT_KAIAK_ADAPTER = 0x46638aD472507482B7D5ba45124E93D16bc97eCE;

    address public BASE_WKAIAK = 0x3703a1DA99a2BDf2d8ce57802aaCb20fb546Ff12;
    address public BASE_WKAIAK_ELEVATED_MINTER_BURNER = 0x4900409aabeCd5DE4ab22D61cdEc4b7478783806;
    address public BASE_OFT_WKAIAK_ADAPTER = 0xB9B3A1baA8CF4C5Cd6b4d132eD7B0cBe05646f6f;

    address public BASE_WBTCK = 0x394239573079a46e438ea6D118Fd96d37A61f270;
    address public BASE_WBTCK_ELEVATED_MINTER_BURNER = 0x54f6Ff27093FC45c5A39083C3Ef0260D25012Be3;
    address public BASE_OFT_WBTCK_ADAPTER = 0xb0FCA55167f94D0f515877C411E0deb904321761;

    address public BASE_WETHK = 0xec32CC0267002618c339274C18AD48D2Bf2A9c7e;
    address public BASE_WETHK_ELEVATED_MINTER_BURNER = 0xfBC915dc39654b52B2E9284FB966C79A1071eA3A;
    address public BASE_OFT_WETHK_ADAPTER = 0x6A58615739b0FC710E6A380E893E672968E30B5F;
    // *******************

    // forge verify-contract --verifier-url https://mainnet-api.kaiascan.io/forge-verify-flatten \
    // --chain-id 8217 \
    // 0x583C963CB88FD42409021039B692646617F77b63 src/MyMintBurnOFTAdapterDecimal2.sol:MyMintBurnOFTAdapterDecimal2 --retries 1

    // forge verify-contract --verifier-url https://mainnet-api.kaiascan.io/forge-verify-flatten \
    // --chain-id 8217 --compiler-version 0.8.28 \
    // 0x583C963CB88FD42409021039B692646617F77b63 MyMintBurnOFTAdapterDecimal2Flattened.sol:MyMintBurnOFTAdapterDecimal2 --retries 1
    // *******************
}
