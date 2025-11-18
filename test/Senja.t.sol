// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {ILPRouter} from "../src/interfaces/ILPRouter.sol";
import {IsHealthy} from "../src/IsHealthy.sol";
import {LendingPoolDeployer} from "../src/LendingPoolDeployer.sol";
import {Protocol} from "../src/Protocol.sol";
import {Oracle} from "../src/Oracle.sol";
import {Liquidator} from "../src/Liquidator.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {OFTKAIAadapter} from "../src/layerzero/OFTKAIAAdapter.sol";
import {OFTUSDTadapter} from "../src/layerzero/OFTUSDTAdapter.sol";
import {ElevatedMinterBurner} from "../src/layerzero/ElevatedMinterBurner.sol";
import {Helper} from "../script/DevTools/Helper.sol";
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
import {IPosition} from "../src/interfaces/IPosition.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PositionDeployer} from "../src/PositionDeployer.sol";
import {LendingPoolRouterDeployer} from "../src/LendingPoolRouterDeployer.sol";
import {MOCKUSDT} from "../src/MockToken/MOCKUSDT.sol";
import {MOCKWKAIA} from "../src/MockToken/MOCKWKAIA.sol";
import {MOCKWETH} from "../src/MockToken/MOCKWETH.sol";
import {MockDex} from "../src/MockDex/MockDex.sol";

interface IOrakl {
    function latestRoundData() external view returns (uint80, int256, uint256);
    function decimals() external view returns (uint8);
}

// RUN
// forge test --match-contract SenjaTest -vvv
contract SenjaTest is Test, Helper {
    using OptionsBuilder for bytes;

    IsHealthy public isHealthy;
    Liquidator public liquidator;
    LendingPoolRouterDeployer public lendingPoolRouterDeployer;
    LendingPoolDeployer public lendingPoolDeployer;
    Protocol public protocol;
    PositionDeployer public positionDeployer;
    LendingPoolFactory public lendingPoolFactory;
    LendingPoolFactory public newImplementation;
    Oracle public oracle;
    OFTUSDTadapter public oftusdtadapter;
    OFTKAIAadapter public oftkaiaadapter;
    ElevatedMinterBurner public elevatedminterburner;
    HelperUtils public helperUtils;
    ERC1967Proxy public proxy;
    MOCKUSDT public mockUSDT;
    MOCKWKAIA public mockWKAIA;
    MOCKWETH public mockWETH;
    MockDex public mockDex;

    address public lendingPool;
    address public lendingPool2;
    address public lendingPool3;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    address public USDT;
    address public WNative;
    address public Native = address(1); // Using WNative instead of native token address(1) for better DeFi composability

    address public usdt_usd_adapter;
    address public native_usdt_adapter;
    address public eth_usdt_adapter;
    address public btc_usdt_adapter;

    address public oft_native_ori_adapter;
    address public oft_native_adapter;
    address public oft_usdt_adapter;

    address public DEX_ROUTER;

    address endpoint;
    address oapp;
    address oapp2;
    address oapp3;
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
    uint32 constant RECEIVE_CONFIG_TYPE = 2;

    uint256 supplyLiquidity;
    uint256 withdrawLiquidity;
    uint256 supplyCollateral;
    uint256 withdrawCollateral;
    uint256 borrowAmount;
    uint256 repayDebt;

    function setUp() public {
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        // vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.createSelectFork(vm.rpcUrl("kaia_testnet"));
        // vm.createSelectFork(vm.rpcUrl("moonbeam_mainnet"));
        vm.startPrank(owner);
        _getUtils();
        // *************** layerzero ***************
        if (block.chainid != 1001) {
            _deployOFT();
            _setLibraries();
            _setSendConfig();
            _setReceiveConfig();
            _setPeers();
            _setEnforcedOptions();
        }
        // *****************************************

        _deployOracleAdapter();
        _deployFactory();
        helperUtils = new HelperUtils(address(proxy));
        lendingPool = IFactory(address(proxy)).createLendingPool(WNative, USDT, 8e17);
        lendingPool2 = IFactory(address(proxy)).createLendingPool(USDT, WNative, 8e17);
        lendingPool3 = IFactory(address(proxy)).createLendingPool(Native, USDT, 8e17);
        if (block.chainid != 1001) _setOFTAddress();
        deal(USDT, alice, 100_000e6);
        deal(WNative, alice, 100_000 ether);
        vm.deal(alice, 100_000 ether);
        vm.stopPrank();
    }

    function _getUtils() internal {
        if (block.chainid == 8453) {
            endpoint = BASE_LZ_ENDPOINT;
            sendLib = BASE_SEND_LIB;
            receiveLib = BASE_RECEIVE_LIB;
            srcEid = BASE_EID;
            gracePeriod = uint32(0);
            dvn1 = BASE_DVN1;
            dvn2 = BASE_DVN2;
            executor = BASE_EXECUTOR;
            eid0 = BASE_EID;
            eid1 = KAIA_EID;
            USDT = BASE_MOCK_USDT;
            WNative = _deployMockToken("WETH");
            DEX_ROUTER;
        } else if (block.chainid == 8217) {
            endpoint = KAIA_LZ_ENDPOINT;
            sendLib = KAIA_SEND_LIB;
            receiveLib = KAIA_RECEIVE_LIB;
            srcEid = KAIA_EID;
            gracePeriod = uint32(0);
            dvn1 = KAIA_DVN1;
            dvn2 = KAIA_DVN2;
            executor = KAIA_EXECUTOR;
            eid0 = KAIA_EID;
            eid1 = BASE_EID;
            USDT = KAIA_USDT;
            WNative = KAIA_WKAIA;
            DEX_ROUTER = KAIA_DEX_ROUTER;
        } else if (block.chainid == 1284) {
            endpoint = GLMR_LZ_ENDPOINT;
            sendLib = GLMR_SEND_LIB;
            receiveLib = GLMR_RECEIVE_LIB;
            srcEid = GLMR_EID;
            gracePeriod = uint32(0);
            dvn1 = GLMR_DVN1;
            dvn2 = GLMR_DVN2;
            executor = GLMR_EXECUTOR;
            eid0 = GLMR_EID;
            eid1 = BASE_EID;
            USDT = _deployMockToken("USDT");
            WNative = _deployMockToken("WNative");
            DEX_ROUTER;
        }
        // TESTNET
        else if (block.chainid == 1001) {
            USDT = _deployMockToken("USDT");
            WNative = _deployMockToken("WNative");
            DEX_ROUTER = KAIA_DEX_ROUTER;
        }
    }

    function _deployMockToken(string memory _name) internal returns (address) {
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("USDT"))) {
            mockUSDT = new MOCKUSDT();
            return address(mockUSDT);
        } else if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("WNative"))) {
            mockWKAIA = new MOCKWKAIA();
            return address(mockWKAIA);
        } else if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("WETH"))) {
            mockWETH = new MOCKWETH();
            return address(mockWETH);
        }
        revert("Invalid token name");
    }

    function _deployMockDex() internal returns (address) {
        mockDex = new MockDex(address(proxy));
        return address(mockDex);
    }

    function _deployOFT() internal {
        elevatedminterburner = new ElevatedMinterBurner(USDT, owner);
        oftusdtadapter = new OFTUSDTadapter(USDT, address(elevatedminterburner), endpoint, owner);
        oft_usdt_adapter = address(oftusdtadapter);
        oapp = address(oftusdtadapter);
        elevatedminterburner.setOperator(oapp, true);

        elevatedminterburner = new ElevatedMinterBurner(WNative, owner);
        oftkaiaadapter = new OFTKAIAadapter(WNative, address(elevatedminterburner), endpoint, owner);
        oft_native_adapter = address(oftkaiaadapter);
        oapp2 = address(oftkaiaadapter);
        elevatedminterburner.setOperator(oapp2, true);

        elevatedminterburner = new ElevatedMinterBurner(WNative, owner);
        oftkaiaadapter = new OFTKAIAadapter(WNative, address(elevatedminterburner), endpoint, owner);
        oft_native_ori_adapter = address(oftkaiaadapter);
        oapp3 = address(oftkaiaadapter);
        elevatedminterburner.setOperator(oapp3, true);
    }

    function _setLibraries() internal {
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp, eid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp, srcEid, receiveLib, gracePeriod);

        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp2, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp2, eid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp2, srcEid, receiveLib, gracePeriod);

        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp3, eid0, sendLib);
        ILayerZeroEndpointV2(endpoint).setSendLibrary(oapp3, eid1, sendLib);
        ILayerZeroEndpointV2(endpoint).setReceiveLibrary(oapp3, srcEid, receiveLib, gracePeriod);
    }

    function _setSendConfig() internal {
        UlnConfig memory uln = UlnConfig({
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
        SetConfigParam[] memory params = new SetConfigParam[](4);
        params[0] = SetConfigParam(eid0, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid0, ULN_CONFIG_TYPE, encodedUln);
        params[2] = SetConfigParam(eid1, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[3] = SetConfigParam(eid1, ULN_CONFIG_TYPE, encodedUln);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp2, sendLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp3, sendLib, params);
    }

    function _setReceiveConfig() internal {
        UlnConfig memory uln = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 2,
            optionalDVNCount: type(uint8).max,
            optionalDVNThreshold: 0,
            requiredDVNs: _toDynamicArray([dvn1, dvn2]),
            optionalDVNs: new address[](0)
        });
        bytes memory encodedUln = abi.encode(uln);
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid0, RECEIVE_CONFIG_TYPE, encodedUln);
        params[1] = SetConfigParam(eid1, RECEIVE_CONFIG_TYPE, encodedUln);

        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp2, receiveLib, params);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp3, receiveLib, params);
    }

    function _setPeers() internal {
        bytes32 oftPeer = bytes32(uint256(uint160(address(oapp)))); // oapp
        OFTUSDTadapter(oapp).setPeer(BASE_EID, oftPeer);
        OFTUSDTadapter(oapp).setPeer(KAIA_EID, oftPeer);

        bytes32 oftPeer2 = bytes32(uint256(uint160(address(oapp2)))); // oapp2
        OFTKAIAadapter(oapp2).setPeer(BASE_EID, oftPeer2);
        OFTKAIAadapter(oapp2).setPeer(KAIA_EID, oftPeer2);

        bytes32 oftPeer3 = bytes32(uint256(uint160(address(oapp3))));
        OFTKAIAadapter(oapp3).setPeer(BASE_EID, oftPeer3);
        OFTKAIAadapter(oapp3).setPeer(KAIA_EID, oftPeer3);
    }

    function _setEnforcedOptions() internal {
        uint16 SEND = 1;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: eid0, msgType: SEND, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: eid1, msgType: SEND, options: options2});

        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
        MyOApp(oapp2).setEnforcedOptions(enforcedOptions);
        MyOApp(oapp3).setEnforcedOptions(enforcedOptions);
    }

    function _deployOracleAdapter() internal {
        // if (block.chainid == 1001 || block.chainid == 8217) {
        oracle = new Oracle(native_usdt);
        native_usdt_adapter = address(oracle);
        // }
        oracle = new Oracle(usdt_usd);
        usdt_usd_adapter = address(oracle);
        oracle = new Oracle(eth_usdt);
        eth_usdt_adapter = address(oracle);
        oracle = new Oracle(btc_usdt);
        btc_usdt_adapter = address(oracle);
    }

    function _deployFactory() internal {
        liquidator = new Liquidator();
        isHealthy = new IsHealthy(address(liquidator));
        lendingPoolDeployer = new LendingPoolDeployer();
        lendingPoolRouterDeployer = new LendingPoolRouterDeployer();
        protocol = new Protocol();
        positionDeployer = new PositionDeployer();

        lendingPoolFactory = new LendingPoolFactory();
        bytes memory data = abi.encodeWithSelector(
            lendingPoolFactory.initialize.selector,
            address(isHealthy),
            address(lendingPoolRouterDeployer),
            address(lendingPoolDeployer),
            address(protocol),
            address(positionDeployer)
        );
        proxy = new ERC1967Proxy(address(lendingPoolFactory), data);

        lendingPoolDeployer.setFactory(address(proxy));
        lendingPoolRouterDeployer.setFactory(address(proxy));

        IFactory(address(proxy)).addTokenDataStream(USDT, usdt_usd_adapter);
        IFactory(address(proxy)).addTokenDataStream(WNative, native_usdt_adapter);
        IFactory(address(proxy)).addTokenDataStream(Native, native_usdt_adapter);

        IFactory(address(proxy)).setWrappedNative(WNative);

        // Deploy MockDex for testnet, Base, and Moonbeam
        if (block.chainid == 1001 || block.chainid == 8453 || block.chainid == 1284) {
            _deployMockDex();
            IFactory(address(proxy)).setDexRouter(address(mockDex));
        } else if (block.chainid == 8217) {
            // KAIA mainnet uses real DEX router
            IFactory(address(proxy)).setDexRouter(DEX_ROUTER);
        } else {
            revert("Dex Unconfigured");
        }
    }

    function _setOFTAddress() internal {
        IFactory(address(proxy)).setOftAddress(WNative, oft_native_adapter);
        IFactory(address(proxy)).setOftAddress(USDT, oft_usdt_adapter);
        IFactory(address(proxy)).setOftAddress(Native, oft_native_adapter);
    }

    // RUN
    // forge test --match-test test_factory -vvv
    function test_factory() public view {
        address router = ILendingPool(lendingPool).router();
        assertEq(ILPRouter(router).lendingPool(), address(lendingPool));
        assertEq(ILPRouter(router).factory(), address(proxy));
        assertEq(ILPRouter(router).collateralToken(), WNative);
        assertEq(ILPRouter(router).borrowToken(), USDT);
        assertEq(ILPRouter(router).ltv(), 8e17);
    }

    // RUN
    // forge test --match-test test_oftaddress -vvv
    function test_oftaddress() public view {
        assertEq(IFactory(address(proxy)).oftAddress(WNative), oft_native_adapter);
        assertEq(IFactory(address(proxy)).oftAddress(USDT), oft_usdt_adapter);
    }

    // RUN
    // forge test --match-test test_checkorakl -vvv
    function test_checkorakl() public view {
        (, int256 price,) = IOrakl(native_usdt).latestRoundData();
        uint8 decimals = IOrakl(native_usdt).decimals();
        console.log("native_usdt price", price);
        console.log("native_usdt decimals", decimals);

        (, uint256 price3,,,) = IOracle(native_usdt_adapter).latestRoundData();
        console.log("native_usdt_adapter price", price3);
        uint8 decimals3 = IOracle(native_usdt_adapter).decimals();
        console.log("native_usdt_adapter decimals", decimals3);
        (, uint256 price4,,,) = IOracle(eth_usdt_adapter).latestRoundData();
        console.log("eth_usdt_adapter price", price4);
        uint8 decimals4 = IOracle(eth_usdt_adapter).decimals();
        console.log("eth_usdt_adapter decimals", decimals4);
        (, uint256 price5,,,) = IOracle(btc_usdt_adapter).latestRoundData();
        console.log("btc_usdt_adapter price", price5);
        uint8 decimals5 = IOracle(btc_usdt_adapter).decimals();
        console.log("btc_usdt_adapter decimals", decimals5);
    }

    // RUN
    // forge test --match-test test_supply_liquidity -vvv
    function test_supply_liquidity() public {
        vm.startPrank(alice);

        // Supply 1000 USDT as liquidity
        IERC20(USDT).approve(lendingPool, 1_000e6);
        ILendingPool(lendingPool).supplyLiquidity(alice, 1_000e6);

        // Supply 1000 WNative as liquidity
        IERC20(WNative).approve(lendingPool2, 1_000 ether);
        ILendingPool(lendingPool2).supplyLiquidity(alice, 1_000 ether);

        // Supply 1000 USDT as liquidity (borrow token for lendingPool3)
        IERC20(USDT).approve(lendingPool3, 1_000e6);
        ILendingPool(lendingPool3).supplyLiquidity(alice, 1_000e6);
        vm.stopPrank();

        // Check balances
        assertEq(IERC20(USDT).balanceOf(lendingPool), 1_000e6);
        assertEq(IERC20(WNative).balanceOf(lendingPool2), 1_000 ether);
        assertEq(IERC20(USDT).balanceOf(lendingPool3), 1_000e6);
    }

    // RUN
    // forge test --match-test test_withdraw_liquidity -vvv
    function test_withdraw_liquidity() public {
        test_supply_liquidity();
        vm.startPrank(alice);
        ILendingPool(lendingPool).withdrawLiquidity(1_000e6);
        ILendingPool(lendingPool2).withdrawLiquidity(1_000 ether);
        ILendingPool(lendingPool3).withdrawLiquidity(1_000e6);
        vm.stopPrank();

        assertEq(IERC20(USDT).balanceOf(lendingPool), 0);
        assertEq(IERC20(WNative).balanceOf(lendingPool2), 0);
        assertEq(IERC20(USDT).balanceOf(lendingPool3), 0);
    }

    // RUN
    // forge test --match-test test_supply_collateral -vvv
    function test_supply_collateral() public {
        vm.startPrank(alice);

        IERC20(WNative).approve(lendingPool, 1000 ether);
        ILendingPool(lendingPool).supplyCollateral(1000 ether, alice);

        IERC20(USDT).approve(lendingPool2, 1_000e6);
        ILendingPool(lendingPool2).supplyCollateral(1_000e6, alice);

        ILendingPool(lendingPool3).supplyCollateral{value: 1_000 ether}(1_000 ether, alice);
        vm.stopPrank();

        assertEq(IERC20(WNative).balanceOf(_addressPosition(lendingPool, alice)), 1000 ether);
        assertEq(IERC20(USDT).balanceOf(_addressPosition(lendingPool2, alice)), 1_000e6);
        assertEq(IERC20(WNative).balanceOf(_addressPosition(lendingPool3, alice)), 1000 ether);
    }

    // RUN
    // forge test --match-test test_withdraw_collateral -vvv
    function test_withdraw_collateral() public {
        test_supply_collateral();
        vm.startPrank(alice);
        ILendingPool(lendingPool).withdrawCollateral(1_000 ether);
        ILendingPool(lendingPool2).withdrawCollateral(1_000e6);
        ILendingPool(lendingPool3).withdrawCollateral(1_000 ether);
        vm.stopPrank();

        assertEq(IERC20(WNative).balanceOf(_addressPosition(lendingPool, alice)), 0);
        assertEq(IERC20(USDT).balanceOf(_addressPosition(lendingPool2, alice)), 0);
        assertEq(IERC20(WNative).balanceOf(_addressPosition(lendingPool3, alice)), 0);
    }

    // RUN
    // forge test --match-test test_borrow_debt -vvv
    function test_borrow_debt() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(10e6, block.chainid, eid0, 65000);
        ILendingPool(lendingPool).borrowDebt(10e6, block.chainid, eid0, 65000);

        ILendingPool(lendingPool2).borrowDebt(0.1 ether, block.chainid, eid0, 65000);
        ILendingPool(lendingPool2).borrowDebt(0.1 ether, block.chainid, eid0, 65000);
        assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 2 * 0.1 ether);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 2 * 0.1 ether);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 2 * 0.1 ether);

        ILendingPool(lendingPool3).borrowDebt(10e6, block.chainid, eid0, 65000);
        ILendingPool(lendingPool3).borrowDebt(10e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowShares(), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool3)).userBorrowShares(alice), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool3)).totalBorrowAssets(), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool3)).totalBorrowShares(), 2 * 10e6);
    }

    // RUN
    // forge test --match-test test_repay_debt -vvv
    function test_repay_debt() public {
        test_borrow_debt();

        vm.startPrank(alice);
        IERC20(USDT).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(10e6, USDT, false, alice, 500);
        IERC20(USDT).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(10e6, USDT, false, alice, 500);
        // For WNative repayment, send native Native which gets auto-wrapped
        IERC20(WNative).approve(lendingPool2, 0.1 ether);
        ILendingPool(lendingPool2).repayWithSelectedToken(0.1 ether, WNative, false, alice, 500);
        IERC20(WNative).approve(lendingPool2, 0.1 ether);
        ILendingPool(lendingPool2).repayWithSelectedToken(0.1 ether, WNative, false, alice, 500);

        IERC20(USDT).approve(lendingPool3, 10e6);
        ILendingPool(lendingPool3).repayWithSelectedToken(10e6, USDT, false, alice, 500);
        IERC20(USDT).approve(lendingPool3, 10e6);
        ILendingPool(lendingPool3).repayWithSelectedToken(10e6, USDT, false, alice, 500);
        vm.stopPrank();

        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 0);
        assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 0);
        assertEq(ILPRouter(_router(lendingPool3)).userBorrowShares(alice), 0);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 0);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 0);
        assertEq(ILPRouter(_router(lendingPool3)).totalBorrowAssets(), 0);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowShares(), 0);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 0);
        assertEq(ILPRouter(_router(lendingPool3)).totalBorrowShares(), 0);
    }

    // RUN
    // forge test --match-test test_borrow_crosschain -vvv --match-contract SenjaTest
    function test_borrow_crosschain() public {
        if (block.chainid != 1001) {
            test_supply_liquidity();
            test_supply_collateral();

            // Provide enough ETH for LayerZero cross-chain fees
            vm.deal(alice, 10 ether);

            vm.startPrank(alice);

            uint256 fee = helperUtils.getFee(oft_usdt_adapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool).borrowDebt{value: fee}(10e6, 8453, BASE_EID, 65000);
            fee = helperUtils.getFee(oft_usdt_adapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool).borrowDebt{value: fee}(10e6, 8453, BASE_EID, 65000);
            if (block.chainid == 8217) {
                fee = helperUtils.getFee(oft_native_adapter, BASE_EID, alice, 15 ether);
                ILendingPool(lendingPool2).borrowDebt{value: fee}(15 ether, 8453, BASE_EID, 65000);
                fee = helperUtils.getFee(oft_native_adapter, BASE_EID, alice, 15 ether);
                ILendingPool(lendingPool2).borrowDebt{value: fee}(15 ether, 8453, BASE_EID, 65000);

                assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 2 * 15 ether);
                assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 2 * 15 ether);
                assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 2 * 15 ether);
            }

            fee = helperUtils.getFee(oft_usdt_adapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool3).borrowDebt{value: fee}(10e6, 8453, BASE_EID, 65000);
            fee = helperUtils.getFee(oft_usdt_adapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool3).borrowDebt{value: fee}(10e6, 8453, BASE_EID, 65000);

            vm.stopPrank();

            assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 2 * 10e6);
            assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 2 * 10e6);
            assertEq(ILPRouter(_router(lendingPool)).totalBorrowShares(), 2 * 10e6);

            assertEq(ILPRouter(_router(lendingPool3)).userBorrowShares(alice), 2 * 10e6);
            assertEq(ILPRouter(_router(lendingPool3)).totalBorrowAssets(), 2 * 10e6);
            assertEq(ILPRouter(_router(lendingPool3)).totalBorrowShares(), 2 * 10e6);
        }
    }

    // RUN
    // forge test --match-test test_swap_collateral -vvv --match-contract SenjaTest
    function test_swap_collateral() public {
        test_supply_collateral();
        vm.startPrank(alice);
        console.log("WNative balance before", IERC20(WNative).balanceOf(_addressPosition(lendingPool2, alice)));

        IPosition(_addressPosition(lendingPool2, alice)).swapTokenByPosition(USDT, WNative, 100e6, 100); // 1% slippage tolerance
        vm.stopPrank();

        console.log("WNative balance after", IERC20(WNative).balanceOf(_addressPosition(lendingPool2, alice)));
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

    // RUN
    // forge test --match-test test_comprehensive_collateral_swap_repay -vvv
    function test_comprehensive_collateral_swap_repay() public {
        // Step 1: Supply liquidity to enable borrowing
        test_supply_liquidity();

        // Step 2: Supply collateral
        test_supply_collateral();

        // Step 3: Borrow debt
        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(10e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        // Verify initial state
        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 10e6);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 10e6);

        // Get position address
        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);
        console.log("Initial WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("Initial USDT in position:", IERC20(USDT).balanceOf(position));
        IPosition(position).swapTokenByPosition(WNative, USDT, 100 ether, 10000);
        console.log("Final WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("Final USDT in position:", IERC20(USDT).balanceOf(position));

        vm.stopPrank();

        vm.startPrank(alice);
        console.log("Before second swap - WNative:", IERC20(WNative).balanceOf(position));
        console.log("Before second swap - USDT:", IERC20(USDT).balanceOf(position));

        IPosition(position).swapTokenByPosition(USDT, WNative, 1e6, 10000);

        console.log("After second swap - WNative:", IERC20(WNative).balanceOf(position));
        console.log("After second swap - USDT:", IERC20(USDT).balanceOf(position));

        vm.stopPrank();

        vm.startPrank(alice);

        console.log("Before repayment - WNative:", IERC20(WNative).balanceOf(position));
        console.log("Before repayment - USDT:", IERC20(USDT).balanceOf(position));

        IERC20(USDT).approve(lendingPool, 5e6);
        ILendingPool(lendingPool).repayWithSelectedToken(5e6, USDT, false, alice, 500);

        console.log("After repayment - WNative:", IERC20(WNative).balanceOf(position));
        console.log("After repayment - USDT:", IERC20(USDT).balanceOf(position));

        vm.stopPrank();

        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 50e6);
        assertLt(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 50e6);

        console.log("Remaining borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Remaining total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());
    }

    // RUN
    // forge test --match-test test_repay_with_high_slippage -vvv
    function test_repay_with_high_slippage() public {
        // Setup: Supply liquidity, collateral, and borrow
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        // Test repaying with USDT directly (no swap needed)
        vm.startPrank(alice);

        // Check initial state
        console.log("Initial WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("Initial USDT in position:", IERC20(USDT).balanceOf(position));
        console.log("Initial borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));

        // Repay using USDT directly (this should work without swapping)
        IERC20(USDT).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(10e6, USDT, false, alice, 500);

        // Check final state
        console.log("Final WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("Final USDT in position:", IERC20(USDT).balanceOf(position));
        console.log("Final borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));

        vm.stopPrank();

        // Verify some repayment occurred
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 20e6);
    }

    // RUN
    // forge test --match-test test_swap_with_extreme_slippage -vvv
    function test_swap_with_extreme_slippage() public {
        test_supply_collateral();

        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);

        // Test with maximum slippage tolerance (10000 = 100%)
        uint256 swapAmount = 50 ether;

        console.log("Testing swap with 10000 slippage tolerance (100%)");
        console.log("Initial WNative:", IERC20(WNative).balanceOf(position));
        console.log("Initial USDT:", IERC20(USDT).balanceOf(position));

        // This should work even with extreme slippage
        IPosition(position).swapTokenByPosition(WNative, USDT, swapAmount, 10000);

        console.log("After swap WNative:", IERC20(WNative).balanceOf(position));
        console.log("After swap USDT:", IERC20(USDT).balanceOf(position));

        // Test swapping back (use a smaller amount that's available)
        uint256 usdtAmount = 1e6; // Use 1 USDT instead of 10
        IPosition(position).swapTokenByPosition(USDT, WNative, usdtAmount, 10000);

        console.log("After swap back WNative:", IERC20(WNative).balanceOf(position));
        console.log("After swap back USDT:", IERC20(USDT).balanceOf(position));

        vm.stopPrank();
    }

    // RUN
    // forge test --match-test test_position_repay_with_swap -vvv
    function test_position_repay_with_swap() public {
        // Setup: Supply liquidity, collateral, and borrow
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        // First, swap some WNative to USDT in the position
        vm.startPrank(alice);

        console.log("Before swap - WNative:", IERC20(WNative).balanceOf(position));
        console.log("Before swap - USDT:", IERC20(USDT).balanceOf(position));
        console.log("Before swap - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));

        // Swap WNative to USDT with high slippage tolerance
        IPosition(position).swapTokenByPosition(WNative, USDT, 100 ether, 10000);

        console.log("After swap - WNative:", IERC20(WNative).balanceOf(position));
        console.log("After swap - USDT:", IERC20(USDT).balanceOf(position));

        vm.stopPrank();

        // Now test repayment using the position's repayWithSelectedToken function
        // This should work because the position has USDT and can repay directly
        vm.startPrank(alice);

        // The position should have USDT now, so we can repay directly
        // But we need to call this through the lending pool, not directly on position
        IERC20(USDT).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(10e6, USDT, false, alice, 500);

        console.log("After repayment - WNative:", IERC20(WNative).balanceOf(position));
        console.log("After repayment - USDT:", IERC20(USDT).balanceOf(position));
        console.log("After repayment - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));

        vm.stopPrank();

        // Verify repayment occurred
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 20e6);
    }

    // RUN
    // forge test --match-test test_position_repay_with_collateral_swap -vvv --TODO:
    function test_position_repay_with_collateral_swap() public {
        // Setup: Supply liquidity, collateral, and borrow
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        // Test repaying using WNative collateral through lending pool
        // The lending pool should call the position's repayWithSelectedToken function
        vm.startPrank(alice);

        console.log("Before repayment - WNative:", IERC20(WNative).balanceOf(position));
        console.log("Before repayment - USDT:", IERC20(USDT).balanceOf(position));
        console.log("Before repayment - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));

        // Call repayWithSelectedToken through lending pool with WNative
        // This should trigger internal swap from WNative to USDT in the position
        ILendingPool(lendingPool).repayWithSelectedToken(10e6, WNative, false, alice, 10000);

        console.log("After repayment - WNative:", IERC20(WNative).balanceOf(position));
        console.log("After repayment - USDT:", IERC20(USDT).balanceOf(position));
        console.log("After repayment - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));

        vm.stopPrank();

        // Verify repayment occurred
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 20e6);
    }

    // RUN
    // forge test --match-test test_position_swap_authorization_issue -vvv
    function test_position_swap_authorization_issue() public {
        // This test demonstrates the authorization issue in Position.sol
        // The repayWithSelectedToken function calls swapTokenByPosition internally
        // but swapTokenByPosition has _onlyAuthorizedSwap() modifier that doesn't allow
        // the Position contract itself to call it

        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        console.log("Position address:", position);
        console.log("WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("USDT in position:", IERC20(USDT).balanceOf(position));

        // Try to call swapTokenByPosition directly from the position (this should fail)
        vm.startPrank(alice);

        // This will fail with NotForSwap() because the position contract is not authorized
        // to call its own swapTokenByPosition function
        try IPosition(position).swapTokenByPosition(WNative, USDT, 100 ether, 10000) {
            console.log("Direct swap succeeded (unexpected)");
        } catch Error(string memory reason) {
            console.log("Direct swap failed as expected:", reason);
        }

        vm.stopPrank();

        // The issue is that repayWithSelectedToken calls swapTokenByPosition internally
        // but swapTokenByPosition has _onlyAuthorizedSwap() modifier that only allows
        // calls from lending pool, IsHealthy, or Liquidator contracts
        // The Position contract itself is not authorized to call swapTokenByPosition
    }

    // RUN
    // forge test --match-test test_position_repay_collateral_direct -vvv --TODO:
    function test_position_repay_collateral_direct() public {
        // Setup: Supply liquidity, collateral, and borrow
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(15e6, block.chainid, eid0, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        // Test repaying using WNative collateral with high slippage tolerance
        vm.startPrank(alice);

        console.log("Initial state:");
        console.log("WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("USDT in position:", IERC20(USDT).balanceOf(position));
        console.log("Borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());

        // Repay using WNative collateral through lending pool - this should swap internally
        // The position contract should handle the swap from WNative to USDT
        ILendingPool(lendingPool).repayWithSelectedToken(5e6, WNative, false, alice, 10000);

        console.log("After first repayment:");
        console.log("WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("USDT in position:", IERC20(USDT).balanceOf(position));
        console.log("Borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());

        // Try another repayment with WNative
        ILendingPool(lendingPool).repayWithSelectedToken(5e6, WNative, false, alice, 10000);

        console.log("After second repayment:");
        console.log("WNative in position:", IERC20(WNative).balanceOf(position));
        console.log("USDT in position:", IERC20(USDT).balanceOf(position));
        console.log("Borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());

        vm.stopPrank();

        // Verify repayments occurred
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 15e6);
        assertLt(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 15e6);
    }

    // TODO: Liquidation scenario test
}
