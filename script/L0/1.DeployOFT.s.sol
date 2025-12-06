// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {sUSDT} from "../../src/BridgeToken/sUSDT.sol";
import {sWKAIA} from "../../src/BridgeToken/sWKAIA.sol";
import {sWBTC} from "../../src/BridgeToken/sWBTC.sol";
import {sKAIA} from "../../src/BridgeToken/sKAIA.sol";
import {sWETH} from "../../src/BridgeToken/sWETH.sol";
import {Helper} from "../DevTools/Helper.sol";
import {ElevatedMinterBurner} from "../../src/layerzero/ElevatedMinterBurner.sol";
import {OFTUSDTadapter} from "../../src/layerzero/OFTUSDTadapter.sol";
import {OFTKAIAadapter} from "../../src/layerzero/OFTKAIAadapter.sol";
import {OFTWBTCadapter} from "../../src/layerzero/OFTWBTCadapter.sol";
import {OFTWETHadapter} from "../../src/layerzero/OFTWETHadapter.sol";

/**
 * @title DeployOFT
 * @notice Deployment script for LayerZero OFT (Omnichain Fungible Token) infrastructure
 * @dev This script deploys bridge tokens, elevated minter/burner contracts, and OFT adapters
 *      across multiple chains (BASE and KAIA). It handles the deployment of wrapped tokens
 *      and their corresponding LayerZero adapters for cross-chain token transfers.
 *
 *      The script inherits from Forge's Script contract for deployment functionality and
 *      Helper contract for accessing chain-specific configuration constants.
 *
 *      Security considerations:
 *      - Ensures proper operator permissions are set for minter/burner contracts
 *      - Uses environment variables for sensitive data (private keys)
 *      - Deploys with specified owner addresses for access control
 */
contract DeployOFT is Script, Helper {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address that will own all deployed contracts
    /// @dev Loaded from PUBLIC_KEY environment variable
    address owner = vm.envAddress("PUBLIC_KEY");

    /// @notice The private key used for broadcasting transactions
    /// @dev Loaded from PRIVATE_KEY environment variable. Should be kept secure.
    uint256 privateKey = vm.envUint("PRIVATE_KEY");

    /// @notice Deployed sUSDT token contract instance
    sUSDT public susdt;

    /// @notice Deployed sWKAIA (Wrapped KAIA) token contract instance
    sWKAIA public swkaia;

    /// @notice Deployed sWBTC (Wrapped BTC) token contract instance
    sWBTC public swbtc;

    /// @notice Deployed sKAIA token contract instance
    sKAIA public skaia;

    /// @notice Deployed sWETH (Wrapped ETH) token contract instance
    sWETH public sweth;

    /// @notice ElevatedMinterBurner contract for managing token minting/burning with elevated privileges
    /// @dev This contract is reused across different token deployments
    ElevatedMinterBurner public elevatedminterburner;

    /// @notice OFT adapter for USDT cross-chain transfers
    OFTUSDTadapter public oftusdtadapter;

    /// @notice OFT adapter for KAIA cross-chain transfers
    OFTKAIAadapter public oftkaiaadapter;

    /// @notice OFT adapter for WBTC cross-chain transfers
    OFTWBTCadapter public oftwbtcadapter;

    /// @notice OFT adapter for WETH cross-chain transfers
    OFTWETHadapter public oftwethadapter;

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Main entry point for the deployment script
     * @dev Executes deployments for BASE and KAIA chains sequentially.
     *      Additional chains (Optimism, HyperEVM) are commented out for future expansion.
     */
    function run() public {
        deployBASE();
        deployKAIA();
        // optimism
        // hyperevm
    }

    /**
     * @notice Deploys OFT infrastructure on BASE mainnet
     * @dev Deploys the following for each supported token (USDT, KAIA, WKAIA, WBTC, WETH):
     *      1. Bridge token contract (e.g., sUSDT, sKAIA)
     *      2. ElevatedMinterBurner contract for managing token supply
     *      3. OFT adapter for LayerZero cross-chain transfers
     *      4. Sets the adapter as an authorized operator on the minter/burner
     *
     *      The function uses Foundry's cheatcodes to:
     *      - Switch to BASE mainnet fork
     *      - Broadcast transactions using the configured private key
     *      - Log deployed contract addresses for reference
     *
     *      Note: BASE_SUSDT, BASE_SKAIA, BASE_SWKAIA, BASE_SWBTC, BASE_SWETH are
     *      constants defined in the Helper contract representing previously deployed addresses.
     */
    function deployBASE() public {
        vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);

        susdt = new sUSDT();
        console.log("address public BASE_SSDT =", address(BASE_SUSDT), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SUSDT), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftusdtadapter = new OFTUSDTadapter(address(BASE_SUSDT), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SUSDT_ADAPTER =", address(oftusdtadapter), ";");
        elevatedminterburner.setOperator(address(oftusdtadapter), true);

        skaia = new sKAIA();
        console.log("address public BASE_SKAIA =", address(BASE_SKAIA), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SKAIA), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter = new OFTKAIAadapter(address(BASE_SKAIA), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SKAIA_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);

        swkaia = new sWKAIA();
        console.log("address public BASE_SWKAIA =", address(BASE_SWKAIA), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SWKAIA), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftkaiaadapter =
            new OFTKAIAadapter(address(BASE_SWKAIA), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SWKAIA_ADAPTER =", address(oftkaiaadapter), ";");
        elevatedminterburner.setOperator(address(oftkaiaadapter), true);

        swbtc = new sWBTC();
        console.log("address public BASE_SWBTC =", address(BASE_SWBTC), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SWBTC), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftwbtcadapter = new OFTWBTCadapter(address(BASE_SWBTC), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SWBTC_ADAPTER =", address(oftwbtcadapter), ";");
        elevatedminterburner.setOperator(address(oftwbtcadapter), true);

        sweth = new sWETH();
        console.log("address public BASE_SWETH =", address(BASE_SWETH), ";");
        elevatedminterburner = new ElevatedMinterBurner(address(BASE_SWETH), owner);
        console.log("address public BASE_ELEVATED_MINTER_BURNER =", address(elevatedminterburner), ";");
        oftwethadapter = new OFTWETHadapter(address(BASE_SWETH), address(elevatedminterburner), BASE_LZ_ENDPOINT, owner);
        console.log("address public BASE_OFT_SWETH_ADAPTER =", address(oftwethadapter), ";");
        elevatedminterburner.setOperator(address(oftwethadapter), true);

        vm.stopBroadcast();
    }

    /**
     * @notice Deploys OFT adapters on KAIA mainnet
     * @dev Deploys OFT adapters for existing tokens on KAIA chain:
     *      - USDT (standard and Stargate version)
     *      - KAIA (native token)
     *      - WKAIA (wrapped KAIA)
     *      - WBTC (wrapped BTC)
     *      - WETH (wrapped ETH)
     *
     *      Unlike BASE deployment, this function only deploys adapters since the tokens
     *      already exist on KAIA. No ElevatedMinterBurner is needed (address(0) is passed)
     *      because these are native KAIA tokens being bridged out.
     *
     *      The function uses Foundry's cheatcodes to:
     *      - Switch to KAIA mainnet fork
     *      - Broadcast transactions using the configured private key
     *      - Log deployed adapter addresses for reference
     *
     *      Constants used (defined in Helper contract):
     *      - KAIA_USDT, KAIA_USDT_STARGATE: USDT token addresses on KAIA
     *      - KAIA_KAIA: Native KAIA token address
     *      - KAIA_WKAIA: Wrapped KAIA token address
     *      - KAIA_WBTC: Wrapped BTC token address
     *      - KAIA_WETH: Wrapped ETH token address
     *      - KAIA_LZ_ENDPOINT: LayerZero endpoint on KAIA chain
     */
    function deployKAIA() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startBroadcast(privateKey);
        console.log("deployed on ChainId: ", block.chainid);

        oftusdtadapter = new OFTUSDTadapter(KAIA_USDT, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_USDT_ADAPTER =", address(oftusdtadapter), ";");

        oftusdtadapter = new OFTUSDTadapter(KAIA_USDT_STARGATE, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_USDT_STARGATE_ADAPTER =", address(oftusdtadapter), ";");

        oftkaiaadapter = new OFTKAIAadapter(KAIA_KAIA, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_KAIA_ADAPTER =", address(oftkaiaadapter), ";");

        oftkaiaadapter = new OFTKAIAadapter(KAIA_WKAIA, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_WKAIA_ADAPTER =", address(oftkaiaadapter), ";");

        oftwbtcadapter = new OFTWBTCadapter(KAIA_WBTC, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_WBTC_ADAPTER =", address(oftwbtcadapter), ";");

        oftwethadapter = new OFTWETHadapter(KAIA_WETH, address(0), KAIA_LZ_ENDPOINT, owner);
        console.log("address public KAIA_OFT_WETH_ADAPTER =", address(oftwethadapter), ";");
        vm.stopBroadcast();
    }
}
// RUN
// forge script DeployOFT --broadcast -vvv --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY
// forge script DeployOFT --broadcast -vvv
// forge script DeployOFT -vvv
