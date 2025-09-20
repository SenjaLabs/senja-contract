// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {IElevatedMintableBurnable} from "../interfaces/IElevatedMintableBurnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OFTadapter is OFTAdapter, ReentrancyGuard {
    error InsufficientBalance();

    address public tokenOFT;
    address public elevatedMinterBurner;

    using SafeERC20 for IERC20;

    constructor(address _token, address _elevatedMinterBurner, address _lzEndpoint, address _owner)
        OFTAdapter(_token, _lzEndpoint, _owner)
        Ownable(_owner)
    {
        tokenOFT = _token;
        elevatedMinterBurner = _elevatedMinterBurner;
    }

    function _credit(address _to, uint256 _amountLD, uint32)
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead);
        if (block.chainid == 8217) {
            if (IERC20(tokenOFT).balanceOf(address(this)) < _amountLD) revert InsufficientBalance();
            IERC20(tokenOFT).safeTransfer(_to, _amountLD);
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).mint(_to, _amountLD);
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
            IERC20(tokenOFT).safeTransferFrom(_from, address(this), amountSentLD);
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).burn(_from, amountSentLD);
        }
    }
}
