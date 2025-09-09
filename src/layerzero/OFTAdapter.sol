// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MintBurnOFTAdapter} from "@layerzerolabs/oft-evm/contracts/MintBurnOFTAdapter.sol";
import {IMintableBurnable} from "@layerzerolabs/oft-evm/contracts/interfaces/IMintableBurnable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISrcEidLib} from "../interfaces/ISrcEidLib.sol";
import {IElevatedMintableBurnable} from "../interfaces/IElevatedMintableBurnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OFTAdapter is MintBurnOFTAdapter, ReentrancyGuard {
    address srcEidLib;
    address tokenOFT;
    address elevatedMinterBurner;

    using SafeERC20 for IERC20;

    constructor(
        address _token, // Your existing ERC20 token with mint/burn exposed
        address _elevatedMinterBurner,
        IMintableBurnable _IminterBurner, // Contract with mint/burn privileges
        address _lzEndpoint, // Local LayerZero endpoint
        address _owner, // Contract owner
        address _srcEidLib // SrcEidLib contract
    ) MintBurnOFTAdapter(_token, _IminterBurner, _lzEndpoint, _owner) Ownable(_owner) {
        srcEidLib = _srcEidLib;
        tokenOFT = _token;
        elevatedMinterBurner = _elevatedMinterBurner;
    }

    function setSrcEidLib(address _srcEidLib) public onlyOwner {
        srcEidLib = _srcEidLib;
    }

    function _credit(address _to, uint256 _amountLD, uint32 srcEid)
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        uint256 realizedAmount =
            (_amountLD * 10 ** IERC20Metadata(tokenOFT).decimals()) / 10 ** ISrcEidLib(srcEidLib).srcDecimals(srcEid);

        if (block.chainid == 8217) {
            IERC20(tokenOFT).safeTransfer(_to, realizedAmount);
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).mint(_to, realizedAmount); // dst kaia release pay borrow, dst other chain mint representative
        }
        return realizedAmount;
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
