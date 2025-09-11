// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {ILPRouter} from "../src/interfaces/ILPRouter.sol";
import {IsHealthy} from "../src/IsHealthy.sol";
import {LendingPoolDeployer} from "../src/LendingPoolDeployer.sol";
import {Protocol} from "../src/Protocol.sol";
import {Oracle} from "../src/Oracle.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {OFTKAIAAdapter} from "../src/layerzero/OFTKAIAAdapter.sol";
import {OFTUSDTAdapter} from "../src/layerzero/OFTUSDTAdapter.sol";
import {ElevatedMinterBurner} from "../src/layerzero/ElevatedMinterBurner.sol";
import {Helper} from "../script/L0/Helper.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {MyOApp} from "../src/layerzero/MyOApp.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperUtils} from "../src/HelperUtils.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";

interface IOrakl {
    function latestRoundData() external view returns (uint80, int256, uint256);
    function decimals() external view returns (uint8);
}

// RUN
// forge test --match-contract SenjaTest -vvv
contract SenjaTest is Test, Helper {
    using OptionsBuilder for bytes;

    IsHealthy public isHealthy;
    LendingPoolDeployer public lendingPoolDeployer;
    Protocol public protocol;
    LendingPoolFactory public lendingPoolFactory;
    Oracle public oracle;
    OFTUSDTAdapter public oftusdtadapter;
    OFTKAIAAdapter public oftkaiaadapter;
    ElevatedMinterBurner public elevatedminterburner;
    HelperUtils public helperUtils;

    address public lendingPool;
    address public lendingPool2;

    address public owner = makeAddr("owner");

    address public alice = makeAddr("alice");

    address public USDT = 0xd077A400968890Eacc75cdc901F0356c943e4fDb;
    address public WKAIA = 0x19Aac5f612f524B754CA7e7c41cbFa2E981A4432;
    address public KAIA = address(1);

    // ORAKL
    address public usdt_usd = 0xa7C4c292Ed720b1318F415B106a443Dc1f052994;
    address public kaia_usdt = 0x9254CD72f207cc231A2307Eac5e4BFa316eb0c2e;
    address public hype_usdt = 0x79e87F197FdAd9d26B5DbadB5789E8f353C421B3;
    address public eth_usdt = 0xbF61f1F8D45EcB33006a335E7c76f306689dcAab;
    address public btc_usdt = 0x624c060ea3fe93321e40530F3f7E587545D594aA;

    address public usdt_usd_adapter;
    address public kaia_usdt_adapter;
    address public hype_usdt_adapter;
    address public eth_usdt_adapter;
    address public btc_usdt_adapter;

    address public kaia_oftkaia_adapter;
    address public kaia_oftusdt_adapter;
    // LayerZero
    uint32 dstEid0 = BASE_EID; // Destination chain EID
    uint32 dstEid1 = KAIA_EID; // Destination chain EID

    address endpoint;
    address oapp;
    address sendLib;
    address receiveLib;
    uint32 srcEid;
    uint32 gracePeriod;

    address dvn1;
    address dvn2;
    address executor;

    uint32 eid0;
    uint32 eid1;
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        vm.startPrank(owner);
        // *************** layerzero ***************
        _deployOFT();
        _setLibraries();
        _setSendConfig();
        _setReceiveConfig();
        _setPeers();
        _setEnforcedOptions();
        // *****************************************

        _deployOracleAdapter();
        _deployFactory();
        helperUtils = new HelperUtils(address(lendingPoolFactory));
        lendingPool = lendingPoolFactory.createLendingPool(KAIA, USDT, 8e17);
        lendingPool2 = lendingPoolFactory.createLendingPool(USDT, KAIA, 8e17);
        _setOFTAddress();
        deal(USDT, alice, 100_000e6);
        vm.deal(alice, 100_000 ether);
        vm.stopPrank();
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            // oapp = BASE_OAPP;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
            executor = BASE_EXECUTOR;
            eid0 = BASE_EID;
            eid1 = KAIA_EID;
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            // oapp = KAIA_OAPP;
            sendLib = KAIA_SEND_LIB;
            receiveLib = KAIA_RECEIVE_LIB;
            srcEid = KAIA_EID;
            gracePeriod = uint32(0);
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
            executor = KAIA_EXECUTOR;
            eid0 = BASE_EID;
            eid1 = KAIA_EID;
        }
    }

    function _deployOFT() internal {
        elevatedminterburner = new ElevatedMinterBurner(USDT, owner);
        oftusdtadapter = new OFTUSDTAdapter(USDT, address(elevatedminterburner), KAIA_LZ_ENDPOINT, owner);
        kaia_oftusdt_adapter = address(oftusdtadapter);
        oapp = address(oftusdtadapter);

        elevatedminterburner = new ElevatedMinterBurner(KAIA, owner);
        oftkaiaadapter = new OFTKAIAAdapter(KAIA, address(elevatedminterburner), KAIA_LZ_ENDPOINT, owner);
        kaia_oftkaia_adapter = address(oftkaiaadapter);
    }

    function _setLibraries() internal {
        _getUtils();
        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp, // OApp address
            dstEid0, // Destination chain EID
            sendLib // SendUln302 address
        );
        ILayerZeroEndpointV2(endpoint).setSendLibrary(
            oapp, // OApp address
            dstEid1, // Destination chain EID
            sendLib // SendUln302 address
        );
        // Set receive library for inbound messages
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(
            oapp, // OApp address
            srcEid, // Source chain EID
            receiveLib, // ReceiveUln302 address
            gracePeriod // Grace period for library switch
        );
    }

    function _setSendConfig() internal {
        _getUtils();
        UlnConfig memory uln;
        uln = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: _toDynamicArray([dvn1, dvn2]),
            optionalDVNs: new address[](0)
        });
        ExecutorConfig memory exec = ExecutorConfig({maxMessageSize: 10000, executor: executor});
        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);
        SetConfigParam[] memory params;
        params = new SetConfigParam[](4);
        params[0] = SetConfigParam(eid0, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid0, ULN_CONFIG_TYPE, encodedUln);
        params[2] = SetConfigParam(eid1, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[3] = SetConfigParam(eid1, ULN_CONFIG_TYPE, encodedUln);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
    }

    function _setReceiveConfig() internal {
        uint32 RECEIVE_CONFIG_TYPE = 2;
        _getUtils();

        UlnConfig memory uln;
        uln = UlnConfig({
            confirmations: 15, // min block confirmations from source (A)
            requiredDVNCount: 2, // required DVNs for message acceptance
            optionalDVNCount: type(uint8).max, // optional DVNs count
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: _toDynamicArray([dvn1, dvn2]), // sorted required DVNs
            optionalDVNs: new address[](0) // no optional DVNs
        });
        bytes memory encodedUln = abi.encode(uln);
        SetConfigParam[] memory params;
        params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid0, RECEIVE_CONFIG_TYPE, encodedUln);
        params[1] = SetConfigParam(eid1, RECEIVE_CONFIG_TYPE, encodedUln);

        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params); // Set config for messages received on B from A
    }

    function _setPeers() internal {
        // For the test environment, we'll use the same OFTUSDTAdapter address as peer
        // This simulates having the same contract deployed on both chains
        bytes32 oftPeer = bytes32(uint256(uint160(address(oftusdtadapter))));

        // Set up peers for the OFTUSDTAdapter (this is what's used for cross-chain transfers)
        OFTUSDTAdapter(oftusdtadapter).setPeer(BASE_EID, oftPeer);
        OFTUSDTAdapter(oftusdtadapter).setPeer(KAIA_EID, oftPeer);

        // Also set up peers for MyOApp if needed
        // (uint32 peer_eid1, bytes32 peer1) = (BASE_EID, bytes32(uint256(uint160(oapp))));
        // (uint32 peer_eid2, bytes32 peer2) = (KAIA_EID, bytes32(uint256(uint160(oapp))));
        // MyOApp(oapp).setPeer(peer_eid1, peer1);
        // MyOApp(oapp).setPeer(peer_eid2, peer2);

        bytes32 oftPeer2 = bytes32(uint256(uint160(address(oftkaiaadapter))));

        // Set up peers for the OFTUSDTAdapter (this is what's used for cross-chain transfers)
        OFTKAIAAdapter(oftkaiaadapter).setPeer(BASE_EID, oftPeer2);
        OFTKAIAAdapter(oftkaiaadapter).setPeer(KAIA_EID, oftPeer2);
    }

    function _setEnforcedOptions() internal {
        uint16 SEND = 1; // Message type for sendString function

        // Destination chain configurations

        // Build options using OptionsBuilder
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        // Create enforced options array
        EnforcedOptionParam[] memory enforcedOptions;
        enforcedOptions = new EnforcedOptionParam[](2);
        // Set enforced options for first destination
        enforcedOptions[0] = EnforcedOptionParam({eid: dstEid0, msgType: SEND, options: options1});
        // Set enforced options for second destination
        enforcedOptions[1] = EnforcedOptionParam({eid: dstEid1, msgType: SEND, options: options2});

        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
    }

    function _deployOracleAdapter() internal {
        oracle = new Oracle(usdt_usd);
        usdt_usd_adapter = address(oracle);
        oracle = new Oracle(kaia_usdt);
        kaia_usdt_adapter = address(oracle);
        oracle = new Oracle(hype_usdt);
        hype_usdt_adapter = address(oracle);
        oracle = new Oracle(eth_usdt);
        eth_usdt_adapter = address(oracle);
        oracle = new Oracle(btc_usdt);
        btc_usdt_adapter = address(oracle);
    }

    function _deployFactory() internal {
        isHealthy = new IsHealthy();
        lendingPoolDeployer = new LendingPoolDeployer();
        protocol = new Protocol();
        lendingPoolFactory = new LendingPoolFactory(address(isHealthy), address(lendingPoolDeployer), address(protocol));

        lendingPoolDeployer.setFactory(address(lendingPoolFactory));

        lendingPoolFactory.addTokenDataStream(USDT, usdt_usd_adapter);
        lendingPoolFactory.addTokenDataStream(KAIA, kaia_usdt_adapter);
        // lendingPoolFactory.addTokenDataStream(ETH, eth_usdt_adapter); // token unavailable
        // lendingPoolFactory.addTokenDataStream(BTC, btc_usdt_adapter); // token unavailable
    }

    function _setOFTAddress() internal {
        lendingPoolFactory.setOftAddress(KAIA, kaia_oftkaia_adapter);
        lendingPoolFactory.setOftAddress(USDT, kaia_oftusdt_adapter);
    }

    // RUN
    // forge test --match-test test_lendingpool_utilities -vvv
    function test_lendingpool_utilities() public view {
        address router = ILendingPool(lendingPool).router();
        assertEq(ILPRouter(router).lendingPool(), address(lendingPool));
        assertEq(ILPRouter(router).factory(), address(lendingPoolFactory));
        assertEq(ILPRouter(router).collateralToken(), KAIA);
        assertEq(ILPRouter(router).borrowToken(), USDT);
        assertEq(ILPRouter(router).ltv(), 8e17);
    }

    // RUN
    // forge test --match-test test_oftaddress -vvv
    function test_oftaddress() public view {
        assertEq(IFactory(address(lendingPoolFactory)).oftAddress(KAIA), kaia_oftkaia_adapter);
        assertEq(IFactory(address(lendingPoolFactory)).oftAddress(USDT), kaia_oftusdt_adapter);
    }

    // RUN
    // forge test --match-test test_checkorakl -vvv
    function test_checkorakl() public view {
        (, int256 price,) = IOrakl(kaia_usdt).latestRoundData();
        uint8 decimals = IOrakl(kaia_usdt).decimals();
        console.log("kaia_usdt price", price);
        console.log("kaia_usdt decimals", decimals);

        (, int256 price2,) = IOrakl(hype_usdt).latestRoundData();
        uint8 decimals2 = IOrakl(hype_usdt).decimals();
        console.log("hype_usdt price", price2);
        console.log("hype_usdt decimals", decimals2);

        (, uint256 price3,,,) = IOracle(kaia_usdt_adapter).latestRoundData();
        console.log("kaia_usdt_adapter price", price3);
        uint8 decimals3 = IOracle(kaia_usdt_adapter).decimals();
        console.log("kaia_usdt_adapter decimals", decimals3);
        (, uint256 price4,,,) = IOracle(hype_usdt_adapter).latestRoundData();
        console.log("hype_usdt_adapter price", price4);
        uint8 decimals4 = IOracle(hype_usdt_adapter).decimals();
        console.log("hype_usdt_adapter decimals", decimals4);
        (, uint256 price5,,,) = IOracle(eth_usdt_adapter).latestRoundData();
        console.log("eth_usdt_adapter price", price5);
        uint8 decimals5 = IOracle(eth_usdt_adapter).decimals();
        console.log("eth_usdt_adapter decimals", decimals5);
        (, uint256 price6,,,) = IOracle(btc_usdt_adapter).latestRoundData();
        console.log("btc_usdt_adapter price", price6);
        uint8 decimals6 = IOracle(btc_usdt_adapter).decimals();
        console.log("btc_usdt_adapter decimals", decimals6);
    }

    // RUN
    // forge test --match-test test_supply_liquidity -vvv
    function test_supply_liquidity() public {
        vm.startPrank(alice);
        IERC20(USDT).approve(lendingPool, 1_000e6);
        ILendingPool(lendingPool).supplyLiquidity(alice, 1_000e6);

        // Supply 1000 KAIA as liquidity (KAIA uses 18 decimals)
        ILendingPool(lendingPool2).supplyLiquidity{value: 1_000 ether}(alice, 1_000 ether);
        vm.stopPrank();

        // assertEq balance usdt of alice position and usdt
        assertEq(IERC20(USDT).balanceOf(lendingPool), 1_000e6);
        assertEq(lendingPool2.balance, 1_000 ether);
    }

    // RUN
    // forge test --match-test test_withdraw_liquidity -vvv
    function test_withdraw_liquidity() public {
        test_supply_liquidity();
        vm.startPrank(alice);
        ILendingPool(lendingPool).withdrawLiquidity(1_000e6);
        ILendingPool(lendingPool2).withdrawLiquidity(1_000 ether);
        vm.stopPrank();

        // assertEq balance usdt of alice position and usdt
        assertEq(IERC20(USDT).balanceOf(lendingPool), 0);
        assertEq(lendingPool2.balance, 0);
    }

    // RUN
    // forge test --match-test test_supply_collateral -vvv
    function test_supply_collateral() public {
        vm.startPrank(alice);
        // Supply 1000 KAIA as collateral (KAIA uses 18 decimals)
        ILendingPool(lendingPool).supplyCollateral{value: 1_000 ether}(1_000 ether, alice);

        // Supply 1000 USDT as collateral (USDT uses 6 decimals)
        IERC20(USDT).approve(lendingPool2, 1_000e6);
        ILendingPool(lendingPool2).supplyCollateral(1_000e6, alice);
        vm.stopPrank();

        assertEq(_addressPosition(lendingPool, alice).balance, 1_000 ether);
        assertEq(IERC20(USDT).balanceOf(_addressPosition(lendingPool2, alice)), 1_000e6);
    }

    // RUN
    // forge test --match-test test_withdraw_collateral -vvv
    function test_withdraw_collateral() public {
        test_supply_collateral();
        vm.startPrank(alice);
        ILendingPool(lendingPool).withdrawCollateral(1_000 ether);
        ILendingPool(lendingPool2).withdrawCollateral(1_000e6);
        vm.stopPrank();

        assertEq(_addressPosition(lendingPool, alice).balance, 0);
        assertEq(IERC20(USDT).balanceOf(_addressPosition(lendingPool2, alice)), 0);
    }

    // RUN
    // forge test --match-test test_borrow_debt -vvv
    function test_borrow_debt() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(120e6, block.chainid, KAIA_EID, 65000);
        ILendingPool(lendingPool2).borrowDebt(50 ether, block.chainid, KAIA_EID, 65000);
        vm.stopPrank();

        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 120e6);
        assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 50 ether);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 120e6);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 50 ether);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowShares(), 120e6);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 50 ether);
    }

    // RUN
    // forge test --match-test test_repay_debt -vvv
    function test_repay_debt() public {
        test_borrow_debt();
        vm.startPrank(alice);
        IERC20(USDT).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(10e6, USDT, false, alice);
        ILendingPool(lendingPool2).repayWithSelectedToken(50 ether, KAIA, false, alice);
        vm.stopPrank();

        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 0);
        assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 0);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 0);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 0);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowShares(), 0);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 0);
    }

    // RUN
    // forge test --match-test test_borrow_crosschain -vvv
    function test_borrow_crosschain() public {
        test_supply_liquidity();
        test_supply_collateral();

        // Provide enough ETH for LayerZero cross-chain fees
        vm.deal(alice, 10 ether);

        vm.startPrank(alice);

        // Test cross-chain borrowing of USDT tokens
        ILendingPool(lendingPool).borrowDebt{value: 1 ether}(10e6, 8453, BASE_EID, 65000);

        // Test cross-chain borrowing of native ETH (from ETH lending pool)
        // ILendingPool(lendingPool2).borrowDebt{value: 1 ether}(0.1 ether, 8453, BASE_EID, 65000);

        vm.stopPrank();
    }

    function _addressPosition(address _lendingPool, address _user) internal view returns (address) {
        return ILPRouter(_router(_lendingPool)).addressPositions(_user);
    }

    function _router(address _lendingPool) internal view returns (address) {
        return ILendingPool(_lendingPool).router();
    }

    function _toDynamicArray(address[2] memory fixedArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);
        dynamicArray[0] = fixedArray[0];
        dynamicArray[1] = fixedArray[1];
        return dynamicArray;
    }
}
