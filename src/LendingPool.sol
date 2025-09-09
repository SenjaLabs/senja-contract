// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OFTAdapter} from "./layerzero/OFTAdapter.sol";
import {Position} from "./Position.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

contract LendingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    error InsufficientCollateral();
    error InsufficientLiquidity();
    error InsufficientShares();
    error LTVExceedMaxAmount();
    error PositionAlreadyCreated();
    error TokenNotAvailable();
    error ZeroAmount();
    error InsufficientBorrowShares();
    error amountSharesInvalid();
    error NotOperator();
    error NotAuthorized(address executor);
    error TransferFailed();
    error InvalidParameter();

    event SupplyLiquidity(address user, uint256 amount, uint256 shares);
    event WithdrawLiquidity(address user, uint256 amount, uint256 shares);
    event SupplyCollateral(address user, uint256 amount);
    event RepayWithCollateralByPosition(address user, uint256 amount, uint256 shares);
    event CreatePosition(address user, address positionAddress);
    event BorrowDebtCrosschain(
        address user, uint256 amount, uint256 shares, uint256 chainId, uint256 addExecutorLzReceiveOption
    );
    event InterestRateModelSet(address indexed oldModel, address indexed newModel);

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;

    mapping(address => uint256) public userSupplyShares;
    mapping(address => uint256) public userBorrowShares;
    mapping(address => address) public addressPositions;

    address public collateralToken;
    address public borrowToken;
    address public factory;
    address public interestRateModel;

    uint256 public lastAccrued;
    uint256 public ltv;

    constructor(
        address _collateralToken,
        address _borrowToken,
        address _factory,
        uint256 _ltv,
        address _interestRateModel
    ) {
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
        factory = _factory;
        ltv = _ltv;
        interestRateModel = _interestRateModel;
    }

    modifier positionRequired() {
        _positionRequired();
        _;
    }

    modifier accessControl(address _user) {
        _accessControl(_user);
        _;
    }

    function _accessControl(address _user) internal view {
        // not operator && user -> authorized -> user supply for himself
        // operator && not user -> authorized -> operator supply for user
        // not operator && not sender -> not authorized -> not authorized
        if (!IFactory(factory).operator(msg.sender)) {
            if (msg.sender != _user) revert NotAuthorized(msg.sender);
        }
    }

    function _positionRequired() internal {
        if (addressPositions[msg.sender] == address(0)) {
            _createPosition();
        }
    }

    /**
     * @notice Creates a new Position contract for the caller if one does not already exist.
     * @dev Each user can have only one Position contract. The Position contract manages collateral and borrowed assets for the user.
     * @custom:throws PositionAlreadyCreated if the caller already has a Position contract.
     * @custom:emits CreatePosition when a new Position is created.
     */
    function _createPosition() internal {
        if (addressPositions[msg.sender] != address(0)) revert PositionAlreadyCreated();
        Position position = new Position(collateralToken, borrowToken, address(this), factory);
        addressPositions[msg.sender] = address(position);
        emit CreatePosition(msg.sender, address(position));
    }

    /**
     * @notice Supply liquidity to the lending pool by depositing borrow tokens.
     * @dev Users receive shares proportional to their deposit. Shares represent ownership in the pool. Accrues interest before deposit.
     * @param _user The address of the user to supply liquidity.
     * @param amount The amount of borrow tokens to supply as liquidity.
     * @custom:throws ZeroAmount if amount is 0.
     * @custom:emits SupplyLiquidity when liquidity is supplied.
     */
    function supplyLiquidity(address _user, uint256 amount) public payable nonReentrant accessControl(_user) {
        if (amount == 0) revert ZeroAmount();

        accrueInterest();
        uint256 shares = 0;

        if (totalSupplyAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupplyShares) / totalSupplyAssets;
        }

        userSupplyShares[_user] += shares;
        totalSupplyShares += shares;
        totalSupplyAssets += amount;

        if (borrowToken == address(0)) {
            // transfer native token
            if (msg.value != amount) revert InsufficientCollateral();
            (bool sent,) = _user.call{value: amount}("");
            if (!sent) revert TransferFailed();
        } else {
            IERC20(borrowToken).safeTransferFrom(_user, address(this), amount);
        }

        emit SupplyLiquidity(_user, amount, shares);
    }

    /**
     * @notice Withdraw supplied liquidity by redeeming shares for underlying tokens.
     * @dev Calculates the corresponding asset amount based on the proportion of total shares. Accrues interest before withdrawal.
     * @param _shares The number of supply shares to redeem for underlying tokens.
     * @custom:throws ZeroAmount if _shares is 0.
     * @custom:throws InsufficientShares if user does not have enough shares.
     * @custom:throws InsufficientLiquidity if protocol lacks liquidity after withdrawal.
     * @custom:emits WithdrawLiquidity when liquidity is withdrawn.
     */
    function withdrawLiquidity(uint256 _shares) public payable nonReentrant {
        if (_shares == 0) revert ZeroAmount();
        if (_shares > userSupplyShares[msg.sender]) revert InsufficientShares();

        accrueInterest();

        uint256 amount = ((_shares * totalSupplyAssets) / totalSupplyShares);

        userSupplyShares[msg.sender] -= _shares;
        totalSupplyShares -= _shares;
        totalSupplyAssets -= amount;

        if (totalSupplyAssets < totalBorrowAssets) {
            revert InsufficientLiquidity();
        }
        if (borrowToken == address(0)) {
            // transfer native token
            (bool sent,) = msg.sender.call{value: amount}("");
            if (!sent) revert TransferFailed();
        } else {
            IERC20(borrowToken).safeTransfer(msg.sender, amount);
        }
        emit WithdrawLiquidity(msg.sender, amount, _shares);
    }

    /**
     * @notice Internal function to calculate and apply accrued interest to the protocol.
     * @dev Uses dynamic interest rate model based on utilization. Updates total supply and borrow assets and last accrued timestamp.
     */
    function accrueInterest() public {
        if (lastAccrued == 0) {
            lastAccrued = block.timestamp;
            return;
        }

        if (totalBorrowAssets == 0) {
            lastAccrued = block.timestamp;
            return;
        }

        IInterestRateModel(interestRateModel).autoAdjustInterestRateModel(totalSupplyAssets, totalBorrowAssets);

        uint256 borrowRate = IInterestRateModel(interestRateModel).getBorrowRate(totalSupplyAssets, totalBorrowAssets);
        uint256 elapsedTime = block.timestamp - lastAccrued;

        // Convert annual rate to the actual interest for the elapsed time
        // borrowRate is in basis points per year, so divide by 10000 for percentage
        uint256 interestPerYear = (totalBorrowAssets * borrowRate) / 10000;
        uint256 interest = (interestPerYear * elapsedTime) / 365 days;

        totalSupplyAssets += interest;
        totalBorrowAssets += interest;
        lastAccrued = block.timestamp;
    }

    /**
     * @notice Set a new interest rate model contract.
     * @dev Only the factory owner can update the interest rate model.
     * @param _newInterestRateModel Address of the new interest rate model contract
     */
    function setInterestRateModel(address _newInterestRateModel) external {
        address owner = IFactory(factory).owner();
        if (msg.sender != owner) revert NotOperator();
        address oldModel = interestRateModel;
        interestRateModel = _newInterestRateModel;
        emit InterestRateModelSet(oldModel, _newInterestRateModel);
    }

    /**
     * @notice Supply collateral tokens to the user's position in the lending pool.
     * @dev Transfers collateral tokens from user to their Position contract. Accrues interest before deposit.
     * @param _amount The amount of collateral tokens to supply.
     * @custom:throws ZeroAmount if amount is 0.
     * @custom:emits SupplyCollateral when collateral is supplied.
     */
    function supplyCollateral(uint256 _amount, address _user)
        public
        payable
        positionRequired
        nonReentrant
        accessControl(_user)
    {
        if (_amount == 0) revert ZeroAmount();
        if (msg.value != _amount) revert InsufficientCollateral();
        accrueInterest();
        if (collateralToken == address(0)) {
            // transfer native token
            (bool sent,) = addressPositions[_user].call{value: _amount}("");
            if (!sent) revert TransferFailed();
        } else {
            IERC20(collateralToken).safeTransferFrom(_user, addressPositions[_user], _amount);
        }

        emit SupplyCollateral(_user, _amount);
    }

    /**
     * @notice Withdraw supplied collateral from the user's position.
     * @dev Transfers collateral tokens from Position contract back to user. Accrues interest before withdrawal.
     * @param _amount The amount of collateral tokens to withdraw.
     * @custom:throws ZeroAmount if amount is 0.
     * @custom:throws InsufficientCollateral if user has insufficient collateral balance.
     */
    function withdrawCollateral(uint256 _amount) public payable positionRequired nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (_amount > IERC20(collateralToken).balanceOf(addressPositions[msg.sender])) revert InsufficientCollateral();
        accrueInterest();
        address isHealthy = IFactory(factory).isHealthy();
        if (collateralToken == address(0)) {
            // transfer native token
            if (msg.value != _amount) revert InsufficientCollateral();
            (bool sent,) = addressPositions[msg.sender].call{value: _amount}("");
            if (!sent) revert TransferFailed();
        } else {
            IPosition(addressPositions[msg.sender]).withdrawCollateral(_amount, msg.sender);
        }

        if (userBorrowShares[msg.sender] > 0) {
            IIsHealthy(isHealthy)._isHealthy(
                borrowToken,
                factory,
                addressPositions[msg.sender],
                ltv,
                totalBorrowAssets,
                totalBorrowShares,
                userBorrowShares[msg.sender]
            );
        }
    }

    /**
     * @notice Borrow assets using supplied collateral and optionally send them to a different network.
     * @dev Calculates shares, checks liquidity, and handles cross-chain or local transfers. Accrues interest before borrowing.
     * @param _amount The amount of tokens to borrow.
     * @param _chainId The chain id of the destination network.
     * @custom:throws InsufficientLiquidity if protocol lacks liquidity.
     * @custom:emits BorrowDebtCrosschain when borrow is successful.
     */
    function borrowDebt(uint256 _amount, uint256 _chainId, uint32 _dstEid, uint128 _addExecutorLzReceiveOption)
        public
        payable
        nonReentrant
    {
        accrueInterest();
        uint256 shares = 0;
        if (totalBorrowShares == 0) {
            shares = _amount;
        } else {
            shares = ((_amount * totalBorrowShares) / totalBorrowAssets);
        }
        userBorrowShares[msg.sender] += shares;
        totalBorrowShares += shares;
        totalBorrowAssets += _amount;

        uint256 protocolFee = (_amount * 1e15) / 1e18; // 0.1%
        uint256 userAmount = _amount - protocolFee;
        address protocol = IFactory(factory).protocol();

        if (totalBorrowAssets > totalSupplyAssets) {
            revert InsufficientLiquidity();
        }
        address isHealthy = IFactory(factory).isHealthy();
        IIsHealthy(isHealthy)._isHealthy(
            borrowToken,
            factory,
            addressPositions[msg.sender],
            ltv,
            totalBorrowAssets,
            totalBorrowShares,
            userBorrowShares[msg.sender]
        );
        if (_chainId != block.chainid) {
            // LAYERZERO IMPLEMENTATION
            bytes memory extraOptions =
                OptionsBuilder.newOptions().addExecutorLzReceiveOption(_addExecutorLzReceiveOption, 0);
            SendParam memory sendParam = SendParam({
                dstEid: _dstEid,
                to: bytes32(uint256(uint160(msg.sender))),
                amountLD: userAmount,
                minAmountLD: userAmount, // 0% slippage tolerance
                extraOptions: extraOptions,
                composeMsg: "",
                oftCmd: ""
            });
            address oftAddress = IFactory(factory).oftAddress(borrowToken);
            OFTAdapter oft = OFTAdapter(oftAddress);
            MessagingFee memory fee = oft.quoteSend(sendParam, false);
            oft.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
        } else {
            if (borrowToken == address(0)) {
                // transfer native token
                (bool sentNative,) = protocol.call{value: protocolFee}("");
                (bool sentToken,) = msg.sender.call{value: userAmount}("");
                if (!sentToken || !sentNative) revert TransferFailed();
            } else {
                IERC20(borrowToken).safeTransfer(protocol, protocolFee);
                IERC20(borrowToken).safeTransfer(msg.sender, userAmount);
            }
        }
        emit BorrowDebtCrosschain(msg.sender, _amount, shares, _chainId, _addExecutorLzReceiveOption);
    }

    /**
     * @notice Repay borrowed assets using a selected token from the user's position.
     * @dev Swaps selected token to borrow token if needed via position contract. Accrues interest before repayment.
     * @param shares The number of borrow shares to repay.
     * @param _token The address of the token to use for repayment.
     * @param _fromPosition Whether to use tokens from the position contract (true) or from the user's wallet (false).
     * @custom:throws ZeroAmount if shares is 0.
     * @custom:throws amountSharesInvalid if shares exceed user's borrow shares.
     * @custom:emits RepayWithCollateralByPosition when repayment is successful.
     */
    function repayWithSelectedToken(uint256 shares, address _token, bool _fromPosition, address _user)
        public
        positionRequired
        nonReentrant
        accessControl(_user)
    {
        if (shares == 0) revert ZeroAmount();
        if (shares > userBorrowShares[_user]) revert amountSharesInvalid();

        accrueInterest();
        uint256 borrowAmount = ((shares * totalBorrowAssets) / totalBorrowShares);
        userBorrowShares[_user] -= shares;
        totalBorrowShares -= shares;
        totalBorrowAssets -= borrowAmount;
        if (_token == borrowToken && !_fromPosition) {
            if (borrowToken == address(0)) {
                // transfer native token
                (bool sent,) = address(this).call{value: borrowAmount}("");
                if (!sent) revert TransferFailed();
            } else {
                IERC20(borrowToken).safeTransferFrom(_user, address(this), borrowAmount);
            }
        } else {
            IPosition(addressPositions[_user]).repayWithSelectedToken(borrowAmount, _token);
        }

        emit RepayWithCollateralByPosition(_user, borrowAmount, shares);
    }
}
