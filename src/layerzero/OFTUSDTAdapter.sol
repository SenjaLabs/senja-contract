// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {IElevatedMintableBurnable} from "../interfaces/IElevatedMintableBurnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice OFTAdapter uses a deployed ERC-20 token and SafeERC20 to interact with the OFTCore contract.
contract OFTUSDTAdapter is OFTAdapter, ReentrancyGuard {
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
        return 6;
    }

    function _credit(address _to, uint256 _amountLD, uint32)
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        if (block.chainid == 8217) {
            IERC20(tokenOFT).safeTransfer(_to, _amountLD);
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
            IERC20(tokenOFT).safeTransferFrom(_from, address(this), amountSentLD);
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).burn(_from, amountSentLD);
        }
    }
}
