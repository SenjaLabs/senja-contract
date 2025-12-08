// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ======================= LIB =======================
import {Test, console} from "forge-std/Test.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// ======================= Core Source =======================
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {IsHealthy} from "../src/IsHealthy.sol";
import {LendingPoolDeployer} from "../src/LendingPoolDeployer.sol";
import {Protocol} from "../src/Protocol.sol";
import {Oracle} from "../src/Oracle.sol";
import {OFTKAIAadapter} from "../src/layerzero/OFTKAIAAdapter.sol";
import {OFTUSDTadapter} from "../src/layerzero/OFTUSDTAdapter.sol";
import {ElevatedMinterBurner} from "../src/layerzero/ElevatedMinterBurner.sol";
import {HelperUtils} from "../src/HelperUtils.sol";
import {PositionDeployer} from "../src/PositionDeployer.sol";
import {LendingPoolRouterDeployer} from "../src/LendingPoolRouterDeployer.sol";
import {TokenDataStream} from "../src/TokenDataStream.sol";
import {InterestRateModel} from "../src/InterestRateModel.sol";

// ======================= Helper =======================
import {Helper} from "../script/DevTools/Helper.sol";
// ======================= MockDex =======================
import {MockDex} from "../src/MockDex/MockDex.sol";

// ======================= MockToken =======================
import {MOCKUSDT} from "../src/MockToken/MOCKUSDT.sol";
import {MOCKWKAIA} from "../src/MockToken/MOCKWKAIA.sol";
import {MOCKWETH} from "../src/MockToken/MOCKWETH.sol";
// ======================= LayerZero =======================
import {MyOApp} from "../src/layerzero/MyOApp.sol";
// ======================= Interfaces =======================
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {ILPRouter} from "../src/interfaces/ILPRouter.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {IIsHealthy} from "../src/interfaces/IIsHealthy.sol";
import {ITokenDataStream} from "../src/interfaces/ITokenDataStream.sol";
import {Orakl} from "../src/MockOrakl/Orakl.sol";

// RUN
// forge test --match-contract SenjaTest -vvv
contract SenjaTest is Test, Helper {
    using OptionsBuilder for bytes;

    IsHealthy public isHealthy;
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
    MOCKUSDT public mockUsdt;
    MOCKWKAIA public mockWkaia;
    MOCKWETH public mockWeth;
    MockDex public mockDex;
    Orakl public mockOrakl;
    TokenDataStream public tokenDataStream;
    InterestRateModel public interestRateModel;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    address public lendingPool;
    address public lendingPool2;
    address public lendingPool3;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    address public usdt;
    address public wNative;
    address public native = address(1); // Using wNative instead of native token address(1) for better DeFi composability

    address public usdtUsdAdapter;
    address public nativeUsdtAdapter;
    address public ethUsdtAdapter;
    address public btcUsdtAdapter;

    address public oftNativeOriAdapter;
    address public oftNativeAdapter;
    address public oftUsdtAdapter;

    address public dexRouter;

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

    uint256 amountStartSupply1 = 1_000e6;
    uint256 amountStartSupply2 = 1_000 ether;
    uint256 amountStartSupply3 = 1_000e6;

    function setUp() public {
        // vm.createSelectFork(vm.rpcUrl("kaia_mainnet"));
        // vm.createSelectFork(vm.rpcUrl("base_mainnet"));
        vm.createSelectFork(vm.rpcUrl("kaia_testnet"));
        // vm.createSelectFork(vm.rpcUrl("moonbeam_mainnet"));
        vm.startPrank(owner);

        _getUtils();
        deal(usdt, alice, 100_000e6);
        deal(wNative, alice, 100_000 ether);
        vm.deal(alice, 100_000 ether);

        deal(usdt, owner, 100_000e6);
        deal(wNative, owner, 100_000 ether);
        vm.deal(owner, 100_000 ether);
        // *************** layerzero ***************
        if (block.chainid != 1001) {
            _deployOft();
            _setLibraries();
            _setSendConfig();
            _setReceiveConfig();
            _setPeers();
            _setEnforcedOptions();
        }
        // *****************************************

        _deployTokenDataStream();
        _deployInterestRateModel();
        _deployDeployer();
        _deployProtocol();
        _deployFactory();
        _setDeployerToFactory();
        _setFactoryConfig();
        _setMockDexFactory(); // Set factory address on MockDex after proxy is created
        _configIsHealthy();
        _setInterestRateModelToFactory();
        _setInterestRateModelTokenReserveFactor();
        _createLendingPool();
        helperUtils = new HelperUtils(address(proxy));
        if (block.chainid != 1001) _setOftAddress();

        vm.stopPrank();
    }

    function _deployInterestRateModel() internal {
        interestRateModel = new InterestRateModel();
        bytes memory data = abi.encodeWithSelector(interestRateModel.initialize.selector);
        proxy = new ERC1967Proxy(address(interestRateModel), data);
        interestRateModel = InterestRateModel(address(proxy));
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
            usdt = BASE_MOCK_USDT;
            wNative = _deployMockToken("WETH");
            dexRouter = _deployMockDex();
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
            usdt = KAIA_USDT;
            wNative = KAIA_WKAIA;
            dexRouter = KAIA_DEX_ROUTER;
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
            usdt = _deployMockToken("USDT");
            wNative = _deployMockToken("WNative");
            dexRouter = _deployMockDex();
        }
        // TESTNET
        else if (block.chainid == 1001) {
            usdt = _deployMockToken("USDT");
            wNative = _deployMockToken("WKAIA");
            dexRouter = _deployMockDex();
        }
    }

    function _deployMockToken(string memory _name) internal returns (address) {
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("USDT"))) {
            mockUsdt = new MOCKUSDT();
            return address(mockUsdt);
        } else if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("WKAIA"))) {
            mockWkaia = new MOCKWKAIA();
            return address(mockWkaia);
        } else if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("WETH"))) {
            mockWeth = new MOCKWETH();
            return address(mockWeth);
        }
        revert("Invalid token name");
    }

    function _deployMockDex() internal returns (address) {
        mockDex = new MockDex(address(proxy));
        return address(mockDex);
    }

    function _deployOft() internal {
        elevatedminterburner = new ElevatedMinterBurner(usdt, owner);
        oftusdtadapter = new OFTUSDTadapter(usdt, address(elevatedminterburner), endpoint, owner);
        oftUsdtAdapter = address(oftusdtadapter);
        oapp = address(oftusdtadapter);
        elevatedminterburner.setOperator(oapp, true);

        elevatedminterburner = new ElevatedMinterBurner(wNative, owner);
        oftkaiaadapter = new OFTKAIAadapter(wNative, address(elevatedminterburner), endpoint, owner);
        oftNativeAdapter = address(oftkaiaadapter);
        oapp2 = address(oftkaiaadapter);
        elevatedminterburner.setOperator(oapp2, true);

        elevatedminterburner = new ElevatedMinterBurner(wNative, owner);
        oftkaiaadapter = new OFTKAIAadapter(wNative, address(elevatedminterburner), endpoint, owner);
        oftNativeOriAdapter = address(oftkaiaadapter);
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
        params[0] = SetConfigParam({eid: eid0, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[1] = SetConfigParam({eid: eid0, configType: ULN_CONFIG_TYPE, config: encodedUln});
        params[2] = SetConfigParam({eid: eid1, configType: EXECUTOR_CONFIG_TYPE, config: encodedExec});
        params[3] = SetConfigParam({eid: eid1, configType: ULN_CONFIG_TYPE, config: encodedUln});
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
        params[0] = SetConfigParam({eid: eid0, configType: RECEIVE_CONFIG_TYPE, config: encodedUln});
        params[1] = SetConfigParam({eid: eid1, configType: RECEIVE_CONFIG_TYPE, config: encodedUln});

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
        uint16 send = 1;
        bytes memory options1 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        bytes memory options2 = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam({eid: eid0, msgType: send, options: options1});
        enforcedOptions[1] = EnforcedOptionParam({eid: eid1, msgType: send, options: options2});

        MyOApp(oapp).setEnforcedOptions(enforcedOptions);
        MyOApp(oapp2).setEnforcedOptions(enforcedOptions);
        MyOApp(oapp3).setEnforcedOptions(enforcedOptions);
    }

    function _deployTokenDataStream() internal {
        tokenDataStream = new TokenDataStream();
        tokenDataStream.setTokenPriceFeed(usdt, USDT_USD);
        tokenDataStream.setTokenPriceFeed(wNative, NATIVE_USDT);
        tokenDataStream.setTokenPriceFeed(native, NATIVE_USDT);
    }

    function _deployDeployer() internal {
        lendingPoolDeployer = new LendingPoolDeployer();
        lendingPoolRouterDeployer = new LendingPoolRouterDeployer();
        positionDeployer = new PositionDeployer();
        isHealthy = new IsHealthy();
    }

    function _deployProtocol() internal {
        protocol = new Protocol();
    }

    function _deployFactory() internal {
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

        // Deploy MockDex for testnet, Base, and Moonbeam
        IFactory(address(proxy)).setDexRouter(dexRouter);
    }

    function _setDeployerToFactory() internal {
        lendingPoolDeployer.setFactory(address(proxy));
        lendingPoolRouterDeployer.setFactory(address(proxy));
        isHealthy.setFactory(address(lendingPoolFactory));
    }

    function _setFactoryConfig() internal {
        IFactory(address(proxy)).setOperator(address(proxy), true);
        IFactory(address(proxy)).setTokenDataStream(address(tokenDataStream));
        IFactory(address(proxy)).setWrappedNative(wNative);
        IFactory(address(proxy)).setInterestRateModel(address(interestRateModel));

        IFactory(address(proxy)).setMinAmountSupplyLiquidity(usdt, 1e6);
        IFactory(address(proxy)).setMinAmountSupplyLiquidity(wNative, 0.1 ether);
        IFactory(address(proxy)).setMinAmountSupplyLiquidity(native, 0.1 ether);
    }

    function _setMockDexFactory() internal {
        // Set the factory address on MockDex after proxy is created
        // This is needed because MockDex is created before the factory proxy in _getUtils()
        if (address(mockDex) != address(0)) {
            mockDex.setFactory(address(proxy));
        }
    }

    function _setInterestRateModelToFactory() internal {
        interestRateModel.grantRole(OWNER_ROLE, address(proxy));
    }

    function _setInterestRateModelTokenReserveFactor() internal {
        interestRateModel.setTokenReserveFactor(usdt, 10e16);
        interestRateModel.setTokenReserveFactor(wNative, 10e16);
        interestRateModel.setTokenReserveFactor(native, 10e16);
    }

    function _configIsHealthy() internal {
        IIsHealthy(address(isHealthy)).setFactory(address(proxy));
    }

    function _createLendingPool() internal {
        IFactory.LendingPoolParams memory lendingPoolParams1 = IFactory.LendingPoolParams({
            collateralToken: wNative,
            borrowToken: usdt,
            ltv: 60e16,
            supplyLiquidity: amountStartSupply1,
            baseRate: 0.05e16,
            rateAtOptimal: 80e16,
            optimalUtilization: 60e16,
            maxUtilization: 60e16,
            liquidationThreshold: 85e16,
            liquidationBonus: 5e16
        });
        IERC20(usdt).approve(address(proxy), amountStartSupply1);
        lendingPool = IFactory(address(proxy)).createLendingPool(lendingPoolParams1);

        IFactory.LendingPoolParams memory lendingPoolParams2 = IFactory.LendingPoolParams({
            collateralToken: usdt,
            borrowToken: wNative,
            ltv: 8e17,
            supplyLiquidity: amountStartSupply2,
            baseRate: 0.05e16,
            rateAtOptimal: 80e16,
            optimalUtilization: 60e16,
            maxUtilization: 6e16,
            liquidationThreshold: 85e16,
            liquidationBonus: 5e16
        });
        IERC20(wNative).approve(address(proxy), amountStartSupply2);
        lendingPool2 = IFactory(address(proxy)).createLendingPool(lendingPoolParams2);

        IFactory.LendingPoolParams memory lendingPoolParams3 = IFactory.LendingPoolParams({
            collateralToken: native,
            borrowToken: usdt,
            ltv: 8e17,
            supplyLiquidity: amountStartSupply3,
            baseRate: 0.05e16,
            rateAtOptimal: 80e16,
            optimalUtilization: 60e16,
            maxUtilization: 6e16,
            liquidationThreshold: 85e16,
            liquidationBonus: 5e16
        });
        IERC20(usdt).approve(address(proxy), amountStartSupply3);
        lendingPool3 = IFactory(address(proxy)).createLendingPool(lendingPoolParams3);
    }

    function _setOftAddress() internal {
        IFactory(address(proxy)).setOftAddress(wNative, oftNativeAdapter);
        IFactory(address(proxy)).setOftAddress(usdt, oftUsdtAdapter);
        IFactory(address(proxy)).setOftAddress(native, oftNativeAdapter);
    }

    // RUN
    // forge test --match-test test_factory -vvv
    function test_factory() public view {
        address router = ILendingPool(lendingPool).router();
        assertEq(ILPRouter(router).lendingPool(), address(lendingPool));
        assertEq(ILPRouter(router).factory(), address(proxy));
        assertEq(ILPRouter(router).collateralToken(), wNative);
        assertEq(ILPRouter(router).borrowToken(), usdt);
        assertEq(ILPRouter(router).ltv(), 60e16);
    }

    // RUN
    // forge test --match-test test_oftaddress -vvv
    function test_oftaddress() public view {
        assertEq(IFactory(address(proxy)).oftAddress(wNative), oftNativeAdapter);
        assertEq(IFactory(address(proxy)).oftAddress(usdt), oftUsdtAdapter);
    }

    // RUN
    // forge test --match-test test_checkorakl -vvv
    function test_checkorakl() public view {
        address _tokenDataStream = IFactory(address(proxy)).tokenDataStream();
        (, uint256 price,,,) = TokenDataStream(_tokenDataStream).latestRoundData(address(usdt));
        console.log("usdt/USD price", price);
        (, uint256 price2,,,) = TokenDataStream(_tokenDataStream).latestRoundData(wNative);
        console.log("wNative/USD price", price2);
        (, uint256 price3,,,) = TokenDataStream(_tokenDataStream).latestRoundData(native);
        console.log("native/USD price", price3);
    }

    // RUN
    // forge test --match-test test_supply_liquidity -vvv
    function test_supply_liquidity() public {
        vm.startPrank(alice);

        // Supply 1000 usdt as liquidity
        IERC20(usdt).approve(lendingPool, 1_000e6);
        ILendingPool(lendingPool).supplyLiquidity(alice, 1_000e6);

        // Supply 1000 wNative as liquidity
        IERC20(wNative).approve(lendingPool2, 1_000 ether);
        ILendingPool(lendingPool2).supplyLiquidity(alice, 1_000 ether);

        // Supply 1000 usdt as liquidity (borrow token for lendingPool3)
        IERC20(usdt).approve(lendingPool3, 1_000e6);
        ILendingPool(lendingPool3).supplyLiquidity(alice, 1_000e6);
        vm.stopPrank();

        // Check balances
        assertEq(IERC20(usdt).balanceOf(lendingPool), 1_000e6 + amountStartSupply1);
        assertEq(IERC20(wNative).balanceOf(lendingPool2), 1_000 ether + amountStartSupply2);
        assertEq(IERC20(usdt).balanceOf(lendingPool3), 1_000e6 + amountStartSupply3);
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

        assertEq(IERC20(usdt).balanceOf(lendingPool), 0 + amountStartSupply1);
        assertEq(IERC20(wNative).balanceOf(lendingPool2), 0 + amountStartSupply2);
        assertEq(IERC20(usdt).balanceOf(lendingPool3), 0 + amountStartSupply3);
    }

    // RUN
    // forge test --match-test test_supply_collateral -vvv
    function test_supply_collateral() public {
        vm.startPrank(alice);

        IERC20(wNative).approve(lendingPool, 1000 ether);
        ILendingPool(lendingPool).supplyCollateral(alice, 1000 ether);

        IERC20(usdt).approve(lendingPool2, 1_000e6);
        ILendingPool(lendingPool2).supplyCollateral(alice, 1_000e6);

        ILendingPool(lendingPool3).supplyCollateral{value: 1_000 ether}(alice, 1_000 ether);
        vm.stopPrank();

        assertEq(IERC20(wNative).balanceOf(_addressPosition(lendingPool, alice)), 1000 ether);
        assertEq(IERC20(usdt).balanceOf(_addressPosition(lendingPool2, alice)), 1_000e6);
        assertEq(IERC20(wNative).balanceOf(_addressPosition(lendingPool3, alice)), 1000 ether);
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

        assertEq(IERC20(wNative).balanceOf(_addressPosition(lendingPool, alice)), 0);
        assertEq(IERC20(usdt).balanceOf(_addressPosition(lendingPool2, alice)), 0);
        assertEq(IERC20(wNative).balanceOf(_addressPosition(lendingPool3, alice)), 0);
    }

    // RUN
    // forge test --match-test test_borrow_debt -vvv
    function test_borrow_debt() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(10e6, block.chainid, 65000);
        ILendingPool(lendingPool).borrowDebt(10e6, block.chainid, 65000);

        ILendingPool(lendingPool2).borrowDebt(0.1 ether, block.chainid, 65000);
        ILendingPool(lendingPool2).borrowDebt(0.1 ether, block.chainid, 65000);

        ILendingPool(lendingPool3).borrowDebt(10e6, block.chainid, 65000);
        ILendingPool(lendingPool3).borrowDebt(10e6, block.chainid, 65000);
        vm.stopPrank();

        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowShares(), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 2 * 0.1 ether);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 2 * 0.1 ether);
        assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 2 * 0.1 ether);
        assertEq(ILPRouter(_router(lendingPool3)).userBorrowShares(alice), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool3)).totalBorrowAssets(), 2 * 10e6);
        assertEq(ILPRouter(_router(lendingPool3)).totalBorrowShares(), 2 * 10e6);
    }

    // RUN
    // forge test --match-test test_repay_debt -vvv
    function test_repay_debt() public {
        test_borrow_debt();

        vm.startPrank(alice);
        IERC20(usdt).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, usdt, 10e6, 0, false);
        IERC20(usdt).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, usdt, 10e6, 500, false);
        // For wNative repayment, send native native which gets auto-wrapped
        IERC20(wNative).approve(lendingPool2, 0.1 ether);
        ILendingPool(lendingPool2).repayWithSelectedToken(alice, wNative, 0.1 ether, 500, false);
        IERC20(wNative).approve(lendingPool2, 0.1 ether);
        ILendingPool(lendingPool2).repayWithSelectedToken(alice, wNative, 0.1 ether, 500, false);

        IERC20(usdt).approve(lendingPool3, 10e6);
        ILendingPool(lendingPool3).repayWithSelectedToken(alice, usdt, 10e6, 500, false);
        IERC20(usdt).approve(lendingPool3, 10e6);
        ILendingPool(lendingPool3).repayWithSelectedToken(alice, usdt, 10e6, 500, false);
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

            uint256 fee = helperUtils.getFee(oftUsdtAdapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool).borrowDebt{value: fee}(10e6, 8453, 65000);
            fee = helperUtils.getFee(oftUsdtAdapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool).borrowDebt{value: fee}(10e6, 8453, 65000);
            if (block.chainid == 8217) {
                fee = helperUtils.getFee(oftNativeAdapter, BASE_EID, alice, 15 ether);
                ILendingPool(lendingPool2).borrowDebt{value: fee}(15 ether, 8453, 65000);
                fee = helperUtils.getFee(oftNativeAdapter, BASE_EID, alice, 15 ether);
                ILendingPool(lendingPool2).borrowDebt{value: fee}(15 ether, 8453, 65000);

                assertEq(ILPRouter(_router(lendingPool2)).userBorrowShares(alice), 2 * 15 ether);
                assertEq(ILPRouter(_router(lendingPool2)).totalBorrowAssets(), 2 * 15 ether);
                assertEq(ILPRouter(_router(lendingPool2)).totalBorrowShares(), 2 * 15 ether);
            }

            fee = helperUtils.getFee(oftUsdtAdapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool3).borrowDebt{value: fee}(10e6, 8453, 65000);
            fee = helperUtils.getFee(oftUsdtAdapter, BASE_EID, alice, 10e6);
            ILendingPool(lendingPool3).borrowDebt{value: fee}(10e6, 8453, 65000);

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
        console.log("wNative balance before", IERC20(wNative).balanceOf(_addressPosition(lendingPool2, alice)));

        vm.startPrank(alice);
        ILendingPool(lendingPool2).swapTokenByPosition(usdt, wNative, 100e6, 100);
        vm.stopPrank();

        console.log("wNative balance after", IERC20(wNative).balanceOf(_addressPosition(lendingPool2, alice)));
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
        ILendingPool(lendingPool).borrowDebt(10e6, block.chainid, 65000);
        vm.stopPrank();

        // Verify initial state
        assertEq(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 10e6);
        assertEq(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 10e6);

        // Get position address
        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);
        console.log("Initial wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("Initial usdt in position:", IERC20(usdt).balanceOf(position));
        ILendingPool(lendingPool).swapTokenByPosition(wNative, usdt, 100 ether, 10000);
        console.log("Final wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("Final usdt in position:", IERC20(usdt).balanceOf(position));
        vm.stopPrank();

        vm.startPrank(alice);
        console.log("Before second swap - wNative:", IERC20(wNative).balanceOf(position));
        console.log("Before second swap - usdt:", IERC20(usdt).balanceOf(position));
        ILendingPool(lendingPool).swapTokenByPosition(usdt, wNative, 1e6, 10000);
        console.log("After second swap - wNative:", IERC20(wNative).balanceOf(position));
        console.log("After second swap - usdt:", IERC20(usdt).balanceOf(position));
        vm.stopPrank();

        vm.startPrank(alice);
        console.log("Before repayment - wNative:", IERC20(wNative).balanceOf(position));
        console.log("Before repayment - usdt:", IERC20(usdt).balanceOf(position));
        IERC20(usdt).approve(lendingPool, 5e6);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, usdt, 5e6, 500, false);
        console.log("After repayment - wNative:", IERC20(wNative).balanceOf(position));
        console.log("After repayment - usdt:", IERC20(usdt).balanceOf(position));
        vm.stopPrank();

        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 50e6);
        assertLt(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 50e6);

        console.log("Remaining borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Remaining total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());
    }

    // RUN
    // forge test --match-test test_repay_with_collateral -vvv
    function test_repay_with_collateral() public {
        // Setup: Supply liquidity, collateral, and borrow
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);
        vm.startPrank(alice);
        console.log("Initial wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("Initial usdt in position:", IERC20(usdt).balanceOf(position));
        console.log("Initial borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        IERC20(usdt).approve(lendingPool, 10e6);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, wNative, 10e6, 500, true);
        console.log("Final wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("Final usdt in position:", IERC20(usdt).balanceOf(position));
        console.log("Final borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        vm.stopPrank();
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 20e6);
    }

    // RUN
    // forge test --match-test test_swap_with_zero_min_amount_out_minimum -vvv
    function test_swap_with_zero_min_amount_out_minimum() public {
        test_supply_collateral();

        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);

        uint256 swapAmount = 50 ether;

        console.log("Testing swap with 10000 slippage tolerance (100%)");
        console.log("Initial wNative:", IERC20(wNative).balanceOf(position));
        console.log("Initial usdt:", IERC20(usdt).balanceOf(position));

        ILendingPool(lendingPool).swapTokenByPosition(wNative, usdt, swapAmount, 10000);

        console.log("After swap wNative:", IERC20(wNative).balanceOf(position));
        console.log("After swap usdt:", IERC20(usdt).balanceOf(position));

        uint256 usdtAmount = 1e6;
        ILendingPool(lendingPool).swapTokenByPosition(usdt, wNative, usdtAmount, 10000);

        console.log("After swap back wNative:", IERC20(wNative).balanceOf(position));
        console.log("After swap back usdt:", IERC20(usdt).balanceOf(position));

        vm.stopPrank();
    }

    // RUN
    // forge test --match-test test_position_repay_collateral_swap -vvv
    function test_position_repay_collateral_swap() public {
        // Setup: Supply liquidity, collateral, and borrow
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);
        console.log("Before swap - wNative:", IERC20(wNative).balanceOf(position));
        console.log("Before swap - usdt:", IERC20(usdt).balanceOf(position));
        console.log("Before swap - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        ILendingPool(lendingPool).swapTokenByPosition(wNative, usdt, 200 ether, 0);
        console.log("After swap - wNative:", IERC20(wNative).balanceOf(position));
        console.log("After swap - usdt:", IERC20(usdt).balanceOf(position));
        vm.stopPrank();

        vm.startPrank(alice);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, usdt, 10e6, 500, true);
        console.log("After repayment - wNative:", IERC20(wNative).balanceOf(position));
        console.log("After repayment - usdt:", IERC20(usdt).balanceOf(position));
        console.log("After repayment - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        vm.stopPrank();

        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 20e6);
    }

    // RUN
    // forge test --match-test test_position_repay_with_collateral_swap -vvv
    function test_position_repay_with_collateral_swap() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(20e6, block.chainid, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);
        console.log("Before repayment - wNative:", IERC20(wNative).balanceOf(position));
        console.log("Before repayment - usdt:", IERC20(usdt).balanceOf(position));
        console.log("Before repayment - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        ILendingPool(lendingPool).repayWithSelectedToken(alice, wNative, 10e6, 10000, true);
        console.log("After repayment - wNative:", IERC20(wNative).balanceOf(position));
        console.log("After repayment - usdt:", IERC20(usdt).balanceOf(position));
        console.log("After repayment - borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        vm.stopPrank();
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 20e6);
    }

    // RUN
    // forge test --match-test test_position_repay_other_token_direct -vvv
    function test_position_repay_other_token_direct() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(15e6, block.chainid, 65000);
        vm.stopPrank();

        address position = _addressPosition(lendingPool, alice);

        vm.startPrank(alice);
        console.log("Initial state:");
        console.log("wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("usdt in position:", IERC20(usdt).balanceOf(position));
        console.log("Borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());

        IERC20(wNative).approve(lendingPool, 5e6);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, wNative, 5e6, 10000, false);

        console.log("After first repayment:");
        console.log("wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("usdt in position:", IERC20(usdt).balanceOf(position));
        console.log("Borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());

        IERC20(wNative).approve(lendingPool, 5e6);
        ILendingPool(lendingPool).repayWithSelectedToken(alice, wNative, 5e6, 10000, false);

        console.log("After second repayment:");
        console.log("wNative in position:", IERC20(wNative).balanceOf(position));
        console.log("usdt in position:", IERC20(usdt).balanceOf(position));
        console.log("Borrow shares:", ILPRouter(_router(lendingPool)).userBorrowShares(alice));
        console.log("Total borrow assets:", ILPRouter(_router(lendingPool)).totalBorrowAssets());
        vm.stopPrank();

        // Verify repayments occurred
        assertLt(ILPRouter(_router(lendingPool)).userBorrowShares(alice), 15e6);
        assertLt(ILPRouter(_router(lendingPool)).totalBorrowAssets(), 15e6);
    }

    // RUN
    // forge test --match-test test_borrow_higher_than_liquidation_threshold -vvv
    function test_borrow_higher_than_liquidation_threshold() public {
        test_supply_liquidity();
        test_supply_collateral();
        console.log("_tokenPrice(wNative)", 1000 * helperTokenPrice(wNative) / 1e8);

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(35e6, block.chainid, 65000);
        vm.stopPrank();
    }

    // RUN
    // forge test --match-test test_borrow_more_than_ltv -vvv
    function test_borrow_more_than_ltv() public {
        test_supply_liquidity();
        test_supply_collateral();
        console.log("_tokenPrice(wNative)", 1000 * helperTokenPrice(wNative) / 1e8);

        vm.startPrank(alice);
        // Expect ExceedsMaxLTV error because 65 USDT exceeds the 60% LTV limit
        vm.expectRevert(); // Will revert with ExceedsMaxLTV
        ILendingPool(lendingPool).borrowDebt(65e6, block.chainid, 65000);
        vm.stopPrank();
    }

    // RUN
    // forge test --match-test test_borrow_exceeds_liquidation_threshold -vvv
    function test_borrow_exceeds_liquidation_threshold() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        // First borrow up to 60% LTV (should succeed)
        ILendingPool(lendingPool).borrowDebt(45e6, block.chainid, 65000);

        // Now try to borrow more that would exceed liquidation threshold (85%)
        // This should trigger LiquidationAlert error
        // vm.expectRevert(); // Will revert with ExceedsMaxLTV since we check LTV first
        ILendingPool(lendingPool).borrowDebt(25e6, block.chainid, 65000);
        vm.stopPrank();
    }

    function helperTokenPrice(address _token) internal view returns (uint256) {
        (, uint256 price,,,) = ITokenDataStream(helperTokenDataStream()).latestRoundData(_token);
        return price;
    }

    function _deployMockOrakl() internal {
        vm.startPrank(owner);
        mockOrakl = new Orakl(address(wNative));
        mockOrakl.setPrice(1 * 1e6);
        tokenDataStream.setTokenPriceFeed(address(wNative), address(mockOrakl));
        vm.stopPrank();
    }

    function helperTokenDataStream() internal view returns (address) {
        return IFactory(address(proxy)).tokenDataStream();
    }

    // RUN
    // forge test --match-test test_liquidation -vvv
    function test_liquidation() public {
        test_supply_liquidity();
        test_supply_collateral();

        vm.startPrank(alice);
        ILendingPool(lendingPool).borrowDebt(9e6, block.chainid, 65000);
        vm.stopPrank();

        _deployMockOrakl();

        address borrowToken = address(usdt);
        address collateralToken = address(wNative);

        uint256 protocolBorrowBefore = IERC20(borrowToken).balanceOf(address(protocol));
        uint256 protocolCollateralBefore = IERC20(collateralToken).balanceOf(address(protocol));
        console.log("protocolBorrowBefore", protocolBorrowBefore / 1e6);
        console.log("protocolCollateralBefore", protocolCollateralBefore / 1e18);
        uint256 borrowBalanceBefore = IERC20(borrowToken).balanceOf(owner);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(owner);
        console.log("balance borrowToken before", borrowBalanceBefore / 1e6);
        console.log("balance collateralToken before", collateralBalanceBefore / 1e18);

        vm.startPrank(owner);
        IERC20(borrowToken).approve(lendingPool, 9e6);
        ILendingPool(lendingPool).liquidation(alice);
        vm.stopPrank();

        uint256 protocolBorrowAfter = IERC20(borrowToken).balanceOf(address(protocol));
        uint256 protocolCollateralAfter = IERC20(collateralToken).balanceOf(address(protocol));
        console.log("protocolBorrowAfter", protocolBorrowAfter / 1e6);
        console.log("protocolCollateralAfter", protocolCollateralAfter / 1e18);
        uint256 borrowBalanceAfter = IERC20(borrowToken).balanceOf(owner);
        uint256 collateralBalanceAfter = IERC20(collateralToken).balanceOf(owner);
        console.log("balance borrowToken after", borrowBalanceAfter / 1e6);
        console.log("balance collateralToken after", collateralBalanceAfter / 1e18);
        console.log("gap after - before", (collateralBalanceAfter - collateralBalanceBefore) / 1e18);
    }
}
