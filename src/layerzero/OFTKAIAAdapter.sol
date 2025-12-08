// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {IElevatedMintableBurnable} from "../interfaces/IElevatedMintableBurnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OFTKAIAadapter
 * @notice LayerZero OFT Adapter for KAIA token cross-chain transfers
 * @dev Enables bridging of KAIA tokens between chains with lock/unlock on source chain (8217) and mint/burn on destination chains
 */
contract OFTKAIAadapter is OFTAdapter, ReentrancyGuard {
    /// @notice Error thrown when contract has insufficient balance for transfer
    error InsufficientBalance();

    /// @notice Emitted when tokens are credited to a user on destination chain
    /// @param to Recipient address
    /// @param amount Amount of tokens credited
    event Credit(address to, uint256 amount);

    /// @notice Emitted when tokens are debited from a user on source chain
    /// @param from Sender address
    /// @param amount Amount of tokens debited
    event Debit(address from, uint256 amount);

    /// @notice Address of the OFT token being bridged
    address public tokenOft;

    /// @notice Address of the elevated minter/burner contract
    address public elevatedMinterBurner;

    using SafeERC20 for IERC20;

    /**
     * @notice Constructs the OFT KAIA Adapter
     * @param _token Address of the KAIA token
     * @param _elevatedMinterBurner Address of the minter/burner contract
     * @param _lzEndpoint Address of the LayerZero endpoint
     * @param _owner Address of the contract owner
     */
    constructor(address _token, address _elevatedMinterBurner, address _lzEndpoint, address _owner)
        OFTAdapter(_token, _lzEndpoint, _owner)
        Ownable(_owner)
    {
        tokenOft = _token;
        elevatedMinterBurner = _elevatedMinterBurner;
    }

    /**
     * @notice Returns the shared decimals used for cross-chain transfers
     * @return Number of shared decimals (18 for KAIA)
     */
    function sharedDecimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Internal function to credit tokens to recipient on destination chain
     * @param _to Recipient address
     * @param _amountLd Amount in local decimals
     * @return amountReceivedLd Amount actually received
     * @dev On chain 8217 (Klaytn), transfers from adapter. On other chains, mints tokens.
     */
    function _credit(address _to, uint256 _amountLd, uint32)
        internal
        virtual
        override
        returns (uint256 amountReceivedLd)
    {
        if (_to == address(0x0)) _to = address(0xdead);
        if (block.chainid == 8217) {
            if (IERC20(tokenOft).balanceOf(address(this)) < _amountLd) revert InsufficientBalance();
            IERC20(tokenOft).safeTransfer(_to, _amountLd);
        } else {
            IElevatedMintableBurnable(elevatedMinterBurner).mint(_to, _amountLd);
        }
        emit Credit(_to, _amountLd);
        return _amountLd;
    }

    /**
     * @notice Internal function to debit tokens from sender on source chain
     * @param _from Sender address
     * @param _amountLd Amount in local decimals
     * @param _minAmountLd Minimum amount to receive
     * @param _dstEid Destination endpoint ID
     * @return amountSentLd Amount sent
     * @return amountReceivedLd Amount to be received on destination
     * @dev On chain 8217 (Klaytn), locks tokens in adapter. On other chains, burns tokens.
     */
    function _debit(address _from, uint256 _amountLd, uint256 _minAmountLd, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLd, uint256 amountReceivedLd)
    {
        (amountSentLd, amountReceivedLd) = _debitView(_amountLd, _minAmountLd, _dstEid);
        if (block.chainid == 8217) {
            IERC20(tokenOft).safeTransferFrom(_from, address(this), amountSentLd);
        } else {
            IERC20(tokenOft).safeTransferFrom(_from, address(this), amountSentLd);
            IERC20(tokenOft).approve(elevatedMinterBurner, amountSentLd);
            IElevatedMintableBurnable(elevatedMinterBurner).burn(_from, amountSentLd);
        }
        emit Debit(_from, _amountLd);
    }

    /**
     * @notice Sets the elevated minter/burner contract address
     * @param _elevatedMinterBurner New minter/burner address
     * @dev Only callable by contract owner
     */
    function setElevatedMinterBurner(address _elevatedMinterBurner) external onlyOwner {
        elevatedMinterBurner = _elevatedMinterBurner;
    }
}
