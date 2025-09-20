// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OFTadapter} from "./layerzero/OFTadapter.sol";
import {OFTKAIAadapter} from "./layerzero/OFTKAIAadapter.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IWKAIA} from "./interfaces/IWKAIA.sol";
import {ILiquidator} from "./interfaces/ILiquidator.sol";

contract LendingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    /// @notice Contract version for tracking upgrades
    uint8 public constant VERSION = 1;

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
    error InsufficientContractBalance();

    event SupplyLiquidity(address user, uint256 amount, uint256 shares);
    event WithdrawLiquidity(address user, uint256 amount, uint256 shares);
    event SupplyCollateral(address user, uint256 amount);
    event RepayByPosition(address user, uint256 amount, uint256 shares);
    event CreatePosition(address user, address positionAddress);
    event BorrowDebtCrosschain(
        address user, uint256 amount, uint256 shares, uint256 chainId, uint256 addExecutorLzReceiveOption
    );
    event InterestRateModelSet(address indexed oldModel, address indexed newModel);

    address public router;

    // Track if we're in a withdrawal operation to avoid auto-wrapping
    bool private _withdrawing;

    constructor(address _router) {
        router = _router;
    }

    modifier positionRequired(address _user) {
        _positionRequired(_user);
        _;
    }

    modifier accessControl(address _user) {
        _accessControl(_user);
        _;
    }

    /**
     * @notice Supply liquidity to the lending pool by depositing borrow tokens.
     * @dev Users receive shares proportional to their deposit. Shares represent ownership in the pool. Accrues interest before deposit.
     * @param _user The address of the user to supply liquidity.
     * @param _amount The amount of borrow tokens to supply as liquidity.
     * @custom:throws ZeroAmount if amount is 0.
     * @custom:emits SupplyLiquidity when liquidity is supplied.
     */
    function supplyLiquidity(address _user, uint256 _amount) public payable nonReentrant accessControl(_user) {
        uint256 shares = _supplyLiquidity(_amount, _user);
        _accrueInterest();
        if (_borrowToken() == address(1)) {
            // Handle native KAIA by wrapping to WKAIA
            if (msg.value != _amount) revert InsufficientCollateral();
            IWKAIA(_WKAIA()).deposit{value: msg.value}();
        } else {
            IERC20(_borrowToken()).safeTransferFrom(_user, address(this), _amount);
        }
        emit SupplyLiquidity(_user, _amount, shares);
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
        uint256 amount = _withdrawLiquidity(_shares);
        bool unwrapToNative = (_borrowToken() == address(1));
        if (unwrapToNative) {
            _withdrawing = true;
            IWKAIA(_WKAIA()).withdraw(amount);
            (bool sent,) = msg.sender.call{value: amount}("");
            if (!sent) revert TransferFailed();
            _withdrawing = false;
        } else {
            IERC20(_borrowToken()).safeTransfer(msg.sender, amount);
        }
        emit WithdrawLiquidity(msg.sender, amount, _shares);
    }

    /**
     * @notice Internal function to calculate and apply accrued interest to the protocol.
     * @dev Uses dynamic interest rate model based on utilization. Updates total supply and borrow assets and last accrued timestamp.
     */
    function _accrueInterest() internal {
        ILPRouter(router).accrueInterest();
    }

    /**
     * @notice Supply collateral tokens to the user's position in the lending pool.
     * @dev Transfers collateral tokens from user to their Position contract. Accrues interest before deposit.
     * @param _amount The amount of collateral tokens to supply.
     * @param _user The address of the user to supply collateral.
     * @custom:throws ZeroAmount if amount is 0.
     * @custom:emits SupplyCollateral when collateral is supplied.
     */
    function supplyCollateral(uint256 _amount, address _user)
        public
        payable
        positionRequired(_user)
        nonReentrant
        accessControl(_user)
    {
        if (_amount == 0) revert ZeroAmount();
        _accrueInterest();
        if (_collateralToken() == address(1)) {
            // Handle native KAIA by wrapping to WKAIA
            if (msg.value != _amount) revert InsufficientCollateral();
            IWKAIA(_WKAIA()).deposit{value: msg.value}();
            IERC20(_WKAIA()).approve(_addressPositions(_user), _amount);
            IERC20(_WKAIA()).safeTransfer(_addressPositions(_user), _amount);
        } else {
            IERC20(_collateralToken()).safeTransferFrom(_user, _addressPositions(_user), _amount);
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
    function withdrawCollateral(uint256 _amount)
        public
        positionRequired(msg.sender)
        nonReentrant
        accessControl(msg.sender)
    {
        if (_amount == 0) revert ZeroAmount();

        uint256 userCollateralBalance;
        if (_collateralToken() == address(1)) {
            userCollateralBalance = IERC20(_WKAIA()).balanceOf(_addressPositions(msg.sender));
        } else {
            userCollateralBalance = IERC20(_collateralToken()).balanceOf(_addressPositions(msg.sender));
        }

        if (_amount > userCollateralBalance) {
            revert InsufficientCollateral();
        }

        _accrueInterest();
        address isHealthy = IFactory(_factory()).isHealthy();

        bool unwrapToNative = (_collateralToken() == address(1));
        IPosition(_addressPositions(msg.sender)).withdrawCollateral(_amount, msg.sender, unwrapToNative);

        if (_userBorrowShares(msg.sender) > 0) {
            IIsHealthy(isHealthy)._isHealthy(
                _borrowToken(),
                _factory(),
                _addressPositions(msg.sender),
                _ltv(),
                _totalBorrowAssets(),
                _totalBorrowShares(),
                _userBorrowShares(msg.sender)
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
        _accrueInterest();

        (uint256 protocolFee, uint256 userAmount, uint256 shares) = _borrowDebt(_amount, msg.sender);

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
            if (_borrowToken() == address(1)) {
                IERC20(_WKAIA()).safeTransfer(_protocol(), protocolFee);
                address oftAddress = IFactory(_factory()).oftAddress(_borrowToken());
                OFTKAIAadapter oft = OFTKAIAadapter(oftAddress);
                IERC20(_WKAIA()).approve(oftAddress, userAmount);
                MessagingFee memory fee = oft.quoteSend(sendParam, false);
                oft.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
            } else {
                IERC20(_borrowToken()).safeTransfer(_protocol(), protocolFee);
                address oftAddress = IFactory(_factory()).oftAddress(_borrowToken());
                OFTadapter oft = OFTadapter(oftAddress);
                IERC20(_borrowToken()).approve(oftAddress, userAmount);
                MessagingFee memory fee = oft.quoteSend(sendParam, false);
                oft.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
            }
        } else {
            if (_borrowToken() == address(1)) {
                _withdrawing = true;
                IWKAIA(_WKAIA()).withdraw(_amount);
                (bool sent,) = _protocol().call{value: protocolFee}("");
                (bool sent2,) = msg.sender.call{value: userAmount}("");
                if (!sent && !sent2) revert TransferFailed();
                _withdrawing = false;
            } else {
                IERC20(_borrowToken()).safeTransfer(_protocol(), protocolFee);
                IERC20(_borrowToken()).safeTransfer(msg.sender, userAmount);
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
     * @custom:emits RepayByPosition when repayment is successful.
     */
    function repayWithSelectedToken(
        uint256 shares,
        address _token,
        bool _fromPosition,
        address _user,
        uint256 _slippageTolerance
    ) public payable positionRequired(_user) nonReentrant accessControl(_user) {
        if (shares == 0) revert ZeroAmount();
        if (shares > _userBorrowShares(_user)) revert amountSharesInvalid();

        _accrueInterest();
        (uint256 borrowAmount,,,) = _repayWithSelectedToken(shares, _user);

        if (_token == _borrowToken() && !_fromPosition) {
            if (_borrowToken() == address(1) && msg.value > 0) {
                if (msg.value != borrowAmount) revert InsufficientCollateral();
                IWKAIA(_WKAIA()).deposit{value: msg.value}();
            } else {
                IERC20(_borrowToken()).safeTransferFrom(_user, address(this), borrowAmount);
            }
        } else {
            IPosition(_addressPositions(_user)).repayWithSelectedToken(borrowAmount, _token, _slippageTolerance);
        }

        emit RepayByPosition(_user, borrowAmount, shares);
    }

    function _accessControl(address _user) internal view {
        if (!IFactory(_factory()).operator(msg.sender)) {
            if (msg.sender != _user) revert NotAuthorized(msg.sender);
        }
    }

    function _positionRequired(address _user) internal {
        if (_addressPositions(_user) == address(0)) {
            _createPosition(_user);
        }
    }

    /**
     * @notice Creates a new Position contract for the caller if one does not already exist.
     * @dev Each user can have only one Position contract. The Position contract manages collateral and borrowed assets for the user.
     * @custom:throws PositionAlreadyCreated if the caller already has a Position contract.
     * @custom:emits CreatePosition when a new Position is created.
     */
    function _createPosition(address _user) internal {
        if (_addressPositions(_user) != address(0)) revert PositionAlreadyCreated();
        ILPRouter(router).createPosition(_user);
        emit CreatePosition(_user, _addressPositions(_user));
    }

    function _borrowToken() internal view returns (address) {
        return ILPRouter(router).borrowToken();
    }

    function _collateralToken() internal view returns (address) {
        return ILPRouter(router).collateralToken();
    }

    function _ltv() internal view returns (uint256) {
        return ILPRouter(router).ltv();
    }

    function _userBorrowShares(address _user) internal view returns (uint256) {
        return ILPRouter(router).userBorrowShares(_user);
    }

    function _addressPositions(address _user) internal view returns (address) {
        return ILPRouter(router).addressPositions(_user);
    }

    function _supplyLiquidity(uint256 _amount, address _user) internal returns (uint256) {
        return ILPRouter(router).supplyLiquidity(_amount, _user);
    }

    function _withdrawLiquidity(uint256 _shares) internal returns (uint256) {
        return ILPRouter(router).withdrawLiquidity(_shares, msg.sender);
    }

    function _borrowDebt(uint256 _amount, address _user) internal returns (uint256, uint256, uint256) {
        return ILPRouter(router).borrowDebt(_amount, _user);
    }

    function _repayWithSelectedToken(uint256 _shares, address _user)
        internal
        returns (uint256, uint256, uint256, uint256)
    {
        return ILPRouter(router).repayWithSelectedToken(_shares, _user);
    }

    function _totalBorrowAssets() internal view returns (uint256) {
        return ILPRouter(router).totalBorrowAssets();
    }

    function _totalBorrowShares() internal view returns (uint256) {
        return ILPRouter(router).totalBorrowShares();
    }

    function _factory() internal view returns (address) {
        return ILPRouter(router).factory();
    }

    function _protocol() internal view returns (address) {
        return IFactory(_factory()).protocol();
    }

    function _WKAIA() internal view returns (address) {
        return IFactory(_factory()).WKAIA();
    }

    function _liquidator() internal view returns (address) {
        return IIsHealthy(_factory()).liquidator();
    }
    /**
     * @notice Liquidates an unhealthy position using DEX swapping
     * @param borrower The address of the borrower to liquidate
     * @param liquidationIncentive The liquidation incentive in basis points (e.g., 500 = 5%)
     * @return liquidatedAmount Amount of debt repaid through liquidation
     * @dev Anyone can call this function to liquidate unhealthy positions
     */

    function liquidateByDEX(address borrower, uint256 liquidationIncentive)
        external
        nonReentrant
        returns (uint256 liquidatedAmount)
    {
        address liquidator = _liquidator();
        return ILiquidator(liquidator).liquidateByDEX(borrower, router, _factory(), liquidationIncentive);
    }

    /**
     * @notice Liquidates an unhealthy position by allowing MEV/external liquidator to buy collateral
     * @param borrower The address of the borrower to liquidate
     * @param repayAmount Amount of debt the liquidator wants to repay
     * @param liquidationIncentive The liquidation incentive in basis points
     * @dev Liquidator pays debt and receives collateral with incentive
     */
    function liquidateByMEV(address borrower, uint256 repayAmount, uint256 liquidationIncentive)
        external
        payable
        nonReentrant
    {
        address liquidator = _liquidator();
        ILiquidator(liquidator).liquidateByMEV{value: msg.value}(
            borrower, router, _factory(), repayAmount, liquidationIncentive
        );
    }

    /**
     * @notice Checks if a borrower's position is liquidatable
     * @param borrower The address of the borrower to check
     * @return isLiquidatable Whether the position can be liquidated
     * @return borrowValue The current borrow value in USD
     * @return collateralValue The current collateral value in USD
     */
    function checkLiquidation(address borrower)
        external
        view
        returns (bool isLiquidatable, uint256 borrowValue, uint256 collateralValue)
    {
        address isHealthy = IFactory(_factory()).isHealthy();
        return IIsHealthy(isHealthy).checkLiquidation(
            _borrowToken(),
            _factory(),
            _addressPositions(borrower),
            _ltv(),
            _totalBorrowAssets(),
            _totalBorrowShares(),
            _userBorrowShares(borrower)
        );
    }

    receive() external payable {
        // Only auto-wrap if this is the native token lending pool and not during withdrawal
        if (msg.value > 0 && !_withdrawing && (_borrowToken() == address(1) || _collateralToken() == address(1))) {
            IWKAIA(_WKAIA()).deposit{value: msg.value}();
        } else if (msg.value > 0 && _withdrawing) {
            // During withdrawal, don't wrap - just pass through
            return;
        } else if (msg.value > 0) {
            // Unexpected native token - revert to prevent loss
            revert("Unexpected native token");
        }
    }

    fallback() external payable {
        // Fallback should not accept native tokens to prevent accidental loss
        revert("Fallback not allowed");
    }
}
