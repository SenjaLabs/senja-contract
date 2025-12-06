// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ILPRouter} from "../../interfaces/ILPRouter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title OAppSupplyLiquidityUSDT
 * @notice LayerZero OApp for cross-chain liquidity supply operations
 * @dev Enables users to supply liquidity to lending pools across different chains using LayerZero messaging
 */
contract OAppSupplyLiquidityUSDT is OApp, OAppOptionsType3 {
    using OptionsBuilder for bytes;
    using SafeERC20 for IERC20;

    /// @notice Error thrown when user has insufficient balance for operation
    error InsufficientBalance();

    /// @notice Error thrown when provided native fee is insufficient
    error InsufficientNativeFee();

    /// @notice Error thrown when caller is not authorized OApp
    error OnlyOApp();

    /// @notice Stores the last received cross-chain message
    bytes public lastMessage;

    /// @notice Address of the factory contract
    address public factory;

    /// @notice Address of the OFT adapter for token bridging
    address public oftaddress;

    /// @notice Message type constant for sending operations
    uint16 public constant SEND = 1;

    /// @notice Emitted when liquidity message is received on destination chain
    /// @param lendingPool Address of the lending pool
    /// @param user Address of the user
    /// @param token Address of the token
    /// @param amount Amount of liquidity
    event SendLiquidityFromDst(address lendingPool, address user, address token, uint256 amount);

    /// @notice Emitted when liquidity message is sent from source chain
    /// @param lendingPool Address of the lending pool
    /// @param user Address of the user
    /// @param token Address of the token
    /// @param amount Amount of liquidity
    event SendLiquidityFromSrc(address lendingPool, address user, address token, uint256 amount);

    /// @notice Emitted when liquidity is executed on destination chain
    /// @param lendingPool Address of the lending pool
    /// @param token Address of the token
    /// @param user Address of the user
    /// @param amount Amount of liquidity supplied
    event ExecuteLiquidity(address lendingPool, address token, address user, uint256 amount);

    /// @notice Tracks pending amounts for each user
    mapping(address => uint256) public userAmount;

    /**
     * @notice Constructs the OAppSupplyLiquidityUSDT contract
     * @param _endpoint Address of the LayerZero endpoint
     * @param _owner Address of the contract owner
     */
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}

    /**
     * @notice Quotes the fee for sending a cross-chain liquidity supply message
     * @param _dstEid Destination endpoint ID
     * @param _lendingPool Address of the destination lending pool
     * @param _user Address of the user
     * @param _token Address of the token
     * @param _amount Amount to supply
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
     * @notice Sends a cross-chain message to supply liquidity on destination chain
     * @param _dstEid Destination endpoint ID
     * @param _lendingPoolDst Address of the destination lending pool
     * @param _user Address of the user
     * @param _tokendst Address of the token on destination chain
     * @param _amount Amount to supply
     * @param _oappFee Native fee for OApp messaging
     * @param _options LayerZero messaging options
     * @dev Emits SendLiquidityFromSrc event
     */
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
        emit SendLiquidityFromDst(_lendingPool, _user, _token, _amount);
    }

    /**
     * @notice Executes the liquidity supply to the lending pool
     * @param _lendingPool Address of the lending pool
     * @param _user Address of the user
     * @param _amount Amount to supply
     * @dev Transfers tokens from this contract to the lending pool and supplies liquidity
     */
    function execute(address _lendingPool, address _user, uint256 _amount) public {
        if (_amount > userAmount[_user]) revert InsufficientBalance();
        userAmount[_user] -= _amount;
        address borrowToken = _borrowToken(_lendingPool);
        IERC20(borrowToken).approve(_lendingPool, _amount);
        ILendingPool(_lendingPool).supplyLiquidity(_user, _amount);
        emit ExecuteLiquidity(_lendingPool, borrowToken, _user, _amount);
    }

    /**
     * @notice Sets the factory contract address
     * @param _factory Address of the factory contract
     * @dev Only callable by contract owner
     */
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    /**
     * @notice Sets the OFT adapter address
     * @param _oftaddress Address of the OFT adapter
     * @dev Only callable by contract owner
     */
    function setOFTaddress(address _oftaddress) public onlyOwner {
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
