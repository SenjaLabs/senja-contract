// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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

/**
 * @title OAppRepayDebtUSDT
 * @notice LayerZero OApp for cross-chain debt repayment operations
 * @dev Enables users to repay debt to lending pools across different chains by combining OFT token transfers with OApp messaging
 */
contract OAppRepayDebtUSDT is OApp, OAppOptionsType3 {
    using OptionsBuilder for bytes;
    using SafeERC20 for IERC20;

    /// @notice Error thrown when user has insufficient balance for operation
    error InsufficientBalance();

    /// @notice Stores the last received cross-chain message
    bytes public lastMessage;

    /// @notice Address of the factory contract
    address public factory;

    /// @notice Address of the OFT adapter for token bridging
    address public oftaddress;

    /// @notice Message type constant for sending operations
    uint16 public constant SEND = 1;

    /// @notice Emitted when debt repayment message is received on destination chain
    /// @param lendingPool Address of the lending pool
    /// @param user Address of the user
    /// @param token Address of the token
    /// @param amount Amount of debt being repaid
    event SendRepayDebtFromDst(address lendingPool, address user, address token, uint256 amount);

    /// @notice Emitted when debt repayment message is sent from source chain
    /// @param lendingPool Address of the lending pool
    /// @param user Address of the user
    /// @param token Address of the token
    /// @param amount Amount of debt being repaid
    event SendRepayDebtFromSrc(address lendingPool, address user, address token, uint256 amount);

    /// @notice Emitted when debt repayment is executed on destination chain
    /// @param lendingPool Address of the lending pool
    /// @param token Address of the token
    /// @param user Address of the user
    /// @param amount Amount of debt repaid
    event ExecuteRepayDebt(address lendingPool, address token, address user, uint256 amount);

    /// @notice Tracks pending amounts for each user
    mapping(address => uint256) public userAmount;

    /**
     * @notice Constructs the OAppRepayDebtUSDT contract
     * @param _endpoint Address of the LayerZero endpoint
     * @param _owner Address of the contract owner
     */
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}

    /**
     * @notice Quotes the fee for sending a cross-chain debt repayment message
     * @param _dstEid Destination endpoint ID
     * @param _lendingPool Address of the destination lending pool
     * @param _user Address of the user
     * @param _token Address of the token
     * @param _amount Amount to repay
     * @param _options LayerZero messaging options
     * @param _payInLzToken Whether to pay fee in LZ token
     * @return fee Calculated messaging fee
     */
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

    /**
     * @notice Sends a cross-chain message to repay debt on destination chain
     * @param _dstEid Destination endpoint ID
     * @param _lendingPool Address of the destination lending pool
     * @param _user Address of the user
     * @param _tokendst Address of the token on destination chain
     * @param _oappaddressdst Address of the OApp contract on destination chain
     * @param _amount Amount to repay
     * @param _slippageTolerance Slippage tolerance in percentage (0-100)
     * @param _options LayerZero messaging options
     * @dev Combines OFT token transfer and OApp messaging in a single transaction
     */
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

        require(msg.value >= oftNativeFee + lzNativeFee, "Insufficient native fee");

        _performOftSend(_dstEid, _oappaddressdst, _user, _amount, _slippageTolerance, oftNativeFee);
        _performLzSend(_dstEid, _lendingPool, _user, _tokendst, _amount, _options, lzNativeFee);
        emit SendRepayDebtFromSrc(_lendingPool, _user, _tokendst, _amount);
    }

    /**
     * @notice Internal function to quote OFT transfer fee
     * @param _dstEid Destination endpoint ID
     * @param _oappaddressdst Address of the OApp on destination chain
     * @param _amount Amount to send
     * @param _slippageTolerance Slippage tolerance in percentage
     * @return Native fee required for OFT transfer
     */
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

    /**
     * @notice Internal function to quote LayerZero messaging fee
     * @param _dstEid Destination endpoint ID
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @param _tokendst Address of the token on destination chain
     * @param _amount Amount to repay
     * @param _options LayerZero messaging options
     * @return Native fee required for LayerZero message
     */
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

    /**
     * @notice Internal function to perform OFT token transfer
     * @param _dstEid Destination endpoint ID
     * @param _oappaddressdst Address of the OApp on destination chain
     * @param _user Address of the user
     * @param _amount Amount to send
     * @param _slippageTolerance Slippage tolerance in percentage
     * @param _oftNativeFee Native fee for OFT transfer
     * @dev Transfers tokens from user, approves OFT adapter, and initiates cross-chain transfer
     */
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
        IERC20(oft.tokenOft()).safeTransferFrom(_user, address(this), _amount);
        IERC20(oft.tokenOft()).approve(oftaddress, _amount);
        oft.send{value: _oftNativeFee}(sendParam, MessagingFee({nativeFee: _oftNativeFee, lzTokenFee: 0}), _user);
    }

    /**
     * @notice Internal function to perform LayerZero message sending
     * @param _dstEid Destination endpoint ID
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @param _tokendst Address of the token on destination chain
     * @param _amount Amount to repay
     * @param _options LayerZero messaging options
     * @param _lzNativeFee Native fee for LayerZero message
     * @dev Sends the cross-chain message with debt repayment details
     */
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
        _lzSend(_dstEid, payload, lzOptions, MessagingFee({nativeFee: _lzNativeFee, lzTokenFee: 0}), payable(_user));
    }

    /**
     * @notice Internal function called by LayerZero when receiving a message
     * @param _message Encoded message containing lending pool, user, token, and amount
     * @dev Increments user's pending amount and stores the message
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata _message, address, bytes calldata) internal override {
        (address _lendingPool, address _user, address _token, uint256 _amount) =
            abi.decode(_message, (address, address, address, uint256));

        userAmount[_user] += _amount;
        lastMessage = _message;
        emit SendRepayDebtFromDst(_lendingPool, _user, _token, _amount);
    }

    /**
     * @notice Executes the debt repayment to the lending pool
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @param _amount Amount to repay
     * @dev Transfers tokens from this contract to the lending pool and repays debt with selected token
     */
    function execute(address _lendingPool, address _user, uint256 _amount) public {
        if (_amount > userAmount[_user]) revert InsufficientBalance();
        userAmount[_user] -= _amount;
        address borrowToken = _borrowToken(_lendingPool);
        IERC20(borrowToken).approve(_lendingPool, _amount);
        ILendingPool(_lendingPool).repayWithSelectedToken(_user, borrowToken, _amount, 500, false);
        emit ExecuteRepayDebt(_lendingPool, borrowToken, _user, _amount);
    }

    /**
     * @notice Sets the factory contract address
     * @param _factory Address of the factory contract
     * @dev Only callable by contract owner. Used on source chain.
     */
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    /**
     * @notice Sets the OFT adapter address
     * @param _oftaddress Address of the OFT adapter
     * @dev Only callable by contract owner. Used on both source and destination chains.
     */
    function setOftAddress(address _oftaddress) public onlyOwner {
        oftaddress = _oftaddress;
    }

    /**
     * @notice Internal function to get the borrow token of a lending pool
     * @param _lendingPool Address of the lending pool
     * @return Address of the borrow token
     */
    function _borrowToken(address _lendingPool) internal view returns (address) {
        return ILPRouter(ILendingPool(_lendingPool).router()).borrowToken();
    }

    /**
     * @notice Converts an address to bytes32 format
     * @param _address Address to convert
     * @return bytes32 representation of the address
     */
    function addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }
}
