// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ILPRouter} from "../../interfaces/ILPRouter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OAppSupplyLiquidityUSDT is OApp, OAppOptionsType3 {
    using OptionsBuilder for bytes;
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error InsufficientNativeFee();
    error OnlyOApp();

    bytes public lastMessage;
    address public factory;
    address public oftaddress;

    uint16 public constant SEND = 1;

    event SendLiquidityFromDst(address lendingPool, address user, address token, uint256 amount);
    event SendLiquidityFromSrc(address lendingPool, address user, address token, uint256 amount);
    event ExecuteLiquidity(address lendingPool, address token, address user, uint256 amount);

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
        address _lendingPoolDst,
        address _user,
        address _tokendst,
        uint256 _amount,
        uint256 _oappFee,
        bytes calldata _options
    ) external payable {
        bytes memory lzOptions = combineOptions(_dstEid, SEND, _options);
        bytes memory message = abi.encode(_lendingPoolDst, _user, _tokendst, _amount);
        _lzSend(_dstEid, message, lzOptions, MessagingFee(_oappFee, 0), payable(_user));
        emit SendLiquidityFromSrc(_lendingPoolDst, _user, _tokendst, _amount);
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata _message, address, bytes calldata) internal override {
        (address _lendingPool, address _user, address _token, uint256 _amount) =
            abi.decode(_message, (address, address, address, uint256));

        userAmount[_user] += _amount;
        lastMessage = _message;
        emit SendLiquidityFromDst(_lendingPool, _user, _token, _amount);
    }

    function execute(address _lendingPool, address _user, uint256 _amount) public {
        if (_amount > userAmount[_user]) revert InsufficientBalance(); // TODO: passing byte code
        userAmount[_user] -= _amount;
        address borrowToken = _borrowToken(_lendingPool);
        IERC20(borrowToken).approve(_lendingPool, _amount);
        ILendingPool(_lendingPool).supplyLiquidity(_user, _amount);
        emit ExecuteLiquidity(_lendingPool, borrowToken, _user, _amount);
    }

    // SRC
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    // SRC - DST
    function setOFTaddress(address _oftaddress) public onlyOwner {
        oftaddress = _oftaddress;
    }

    function _borrowToken(address _lendingPool) internal view returns (address) {
        return ILPRouter(ILendingPool(_lendingPool).router()).borrowToken();
    }

    function addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }
}
