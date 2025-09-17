// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OFTadapter} from "../OFTAdapter.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ILPRouter} from "../../interfaces/ILPRouter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OAppSupplyCollateralUSDT is OApp, OAppOptionsType3 {
    using OptionsBuilder for bytes;
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error InsufficientNativeFee();

    bytes public lastMessage;
    address public factory;
    address public oftaddress;

    uint16 public constant SEND = 1;

    event SendCollateralFromDst(address lendingPool, address user, address token, uint256 amount);
    event SendCollateralFromSrc(address lendingPool, address user, address token, uint256 amount);
    event ExecuteCollateral(address lendingPool, address token, address user, uint256 amount);

    mapping(address => uint256) public userAmount;

    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}

    function quoteSendString(
        uint32 _dstEid,
        address _lendingPool,
        address _user,
        address _token,
        uint256 _amount,
        bytes calldata _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory _message = abi.encode(_lendingPool, _user, _token, _amount);
        fee = _quote(_dstEid, _message, combineOptions(_dstEid, SEND, _options), _payInLzToken);
    }

    function sendString(
        uint32 _dstEid,
        address _lendingPool,
        address _user,
        address _tokendst,
        address _oappaddressdst,
        uint256 _amount,
        uint256 _slippageTolerance,
        bytes calldata _options
    ) external payable {
        uint256 oftNativeFee = _quoteOftNativeFee(_dstEid, _oappaddressdst, _amount, _slippageTolerance);
        uint256 lzNativeFee = _quoteLzNativeFee(_dstEid, _lendingPool, _user, _tokendst, _amount, _options);

        if (msg.value < oftNativeFee + lzNativeFee) revert InsufficientNativeFee();

        _performOftSend(_dstEid, _oappaddressdst, _user, _amount, _slippageTolerance, oftNativeFee);
        _performLzSend(_dstEid, _lendingPool, _user, _tokendst, _amount, _options, lzNativeFee);
        emit SendCollateralFromSrc(_lendingPool, _user, _tokendst, _amount);
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata _message, address, bytes calldata) internal override {
        (address _lendingPool, address _user, address _token, uint256 _amount) =
            abi.decode(_message, (address, address, address, uint256));

        userAmount[_user] += _amount;
        lastMessage = _message;
        emit SendCollateralFromDst(_lendingPool, _user, _token, _amount);
    }

    function execute(address _lendingPool, address _user, uint256 _amount) public {
        if (_amount > userAmount[_user]) revert InsufficientBalance();
        userAmount[_user] -= _amount;
        address collateralToken = _collateralToken(_lendingPool);
        IERC20(collateralToken).approve(_lendingPool, _amount);
        ILendingPool(_lendingPool).supplyCollateral(_amount, _user);
        emit ExecuteCollateral(_lendingPool, collateralToken, _user, _amount);
    }

    function _quoteOftNativeFee(uint32 _dstEid, address _oappaddressdst, uint256 _amount, uint256 _slippageTolerance)
        internal
        view
        returns (uint256)
    {
        OFTadapter oft = OFTadapter(oftaddress);
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: addressToBytes32(_oappaddressdst),
            amountLD: _amount,
            minAmountLD: _amount * (100 - _slippageTolerance) / 100,
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        return oft.quoteSend(sendParam, false).nativeFee;
    }

    function _quoteLzNativeFee(
        uint32 _dstEid,
        address _lendingPool,
        address _user,
        address _tokendst,
        uint256 _amount,
        bytes calldata _options
    ) internal view returns (uint256) {
        bytes memory lzOptions = combineOptions(_dstEid, SEND, _options);
        bytes memory payload = abi.encode(_lendingPool, _user, _tokendst, _amount);
        return _quote(_dstEid, payload, lzOptions, false).nativeFee;
    }

    function _performOftSend(
        uint32 _dstEid,
        address _oappaddressdst,
        address _user,
        uint256 _amount,
        uint256 _slippageTolerance,
        uint256 _oftNativeFee
    ) internal {
        OFTadapter oft = OFTadapter(oftaddress);
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: addressToBytes32(_oappaddressdst),
            amountLD: _amount,
            minAmountLD: _amount * (100 - _slippageTolerance) / 100,
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        IERC20(oft.tokenOFT()).safeTransferFrom(_user, address(this), _amount);
        IERC20(oft.tokenOFT()).approve(oftaddress, _amount);
        oft.send{value: _oftNativeFee}(sendParam, MessagingFee(_oftNativeFee, 0), _user);
    }

    function _performLzSend(
        uint32 _dstEid,
        address _lendingPool,
        address _user,
        address _tokendst,
        uint256 _amount,
        bytes calldata _options,
        uint256 _lzNativeFee
    ) internal {
        bytes memory lzOptions = combineOptions(_dstEid, SEND, _options);
        bytes memory payload = abi.encode(_lendingPool, _user, _tokendst, _amount);
        _lzSend(_dstEid, payload, lzOptions, MessagingFee(_lzNativeFee, 0), payable(_user));
    }

    // SRC
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    // SRC - DST
    function setOFTaddress(address _oftaddress) public onlyOwner {
        oftaddress = _oftaddress;
    }

    function _collateralToken(address _lendingPool) internal view returns (address) {
        return ILPRouter(ILendingPool(_lendingPool).router()).collateralToken();
    }

    function addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }
}
