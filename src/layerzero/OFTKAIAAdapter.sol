// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IElevatedMintableBurnable} from "../interfaces/IElevatedMintableBurnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OFTKAIAAdapter is OFTAdapter, ReentrancyGuard {
    error CreditFailed(address _to, uint256 _amountLD, string _reason);
    error InsufficientNativeValue(uint256 required, uint256 provided);

    address tokenOFT;
    address elevatedMinterBurner;

    using SafeERC20 for IERC20;

    constructor(
        address _token, // Your existing ERC20 token with mint/burn exposed
        address _elevatedMinterBurner,
        address _lzEndpoint, // Local LayerZero endpoint
        address _owner // Contract owner
    ) OFTAdapter(_token, _lzEndpoint, _owner) Ownable(_owner) {
        tokenOFT = _token;
        elevatedMinterBurner = _elevatedMinterBurner;
    }

    function sharedDecimals() public pure override returns (uint8) {
        return 18;
    }

    // Allow contract to receive native KAIA
    receive() external payable {}

    // Payable wrapper for sending native KAIA to other chains
    function sendNativeKAIA(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
    {
        require(block.chainid == 8217, "Only available on KAIA chain");
        require(msg.value >= _sendParam.amountLD, "Insufficient native KAIA sent");

        // Call the inherited send function
        _send(_sendParam, _fee, _refundAddress);

        // Refund excess native KAIA
        if (msg.value > _sendParam.amountLD) {
            (bool success,) = msg.sender.call{value: msg.value - _sendParam.amountLD}("");
            require(success, "Refund failed");
        }
    }

    function _credit(address _to, uint256 _amountLD, uint32)
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        if (block.chainid == 8217) {
            (bool success,) = _to.call{value: _amountLD}("");
            if (!success) revert CreditFailed(_to, _amountLD, "");
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).mint(_to, _amountLD); // dst kaia release pay borrow, dst other chain mint representative
        }
        return _amountLD;
    }

    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        if (block.chainid == 8217) {
            // For native KAIA, verify contract has sufficient balance
            // Note: Native KAIA should be sent via msg.value in the calling function
            if (address(this).balance < amountSentLD) {
                revert InsufficientNativeValue(amountSentLD, address(this).balance);
            }
            // Native KAIA is already held by the contract, no transfer needed
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).burn(_from, amountSentLD);
        }
    }
}
