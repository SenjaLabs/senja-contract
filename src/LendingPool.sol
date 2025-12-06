// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OFTadapter} from "./layerzero/OFTadapter.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {IWrappedNative} from "./interfaces/IWrappedNative.sol";
import {ILiquidator} from "./interfaces/ILiquidator.sol";
import {ITokenDataStream} from "./interfaces/ITokenDataStream.sol";

/**
 * @title LendingPool
 * @notice Core lending pool contract for supplying liquidity, borrowing, and managing collateral
 * @dev Implements lending pool functionality with cross-chain borrowing via LayerZero and position-based collateral management
 */
contract LendingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    /// @notice Contract version for tracking upgrades
    uint8 public constant VERSION = 1;

    /// @notice Thrown when user has insufficient collateral for an operation
    /// @param amount Requested amount
    /// @param expectedAmount Required amount
    error InsufficientCollateral(uint256 amount, uint256 expectedAmount);

    /// @notice Thrown when zero amount is provided
    error ZeroAmount();

    /// @notice Thrown when shares amount is invalid
    /// @param shares Requested shares
    /// @param userBorrowShares User's actual borrow shares
    error amountSharesInvalid(uint256 shares, uint256 userBorrowShares);

    /// @notice Thrown when caller is not authorized
    /// @param executor Address of unauthorized caller
    error NotAuthorized(address executor);

    /// @notice Thrown when token transfer fails
    /// @param amount Amount that failed to transfer
    error TransferFailed(uint256 amount);

    /// @notice Thrown when swap parameters are invalid
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    error SwapTokenByPositionInvalidParameter(address tokenIn, address tokenOut);

    /// @notice Thrown when oracle is not set for a token
    /// @param token Token address missing oracle
    error OracleOnTokenNotSet(address token);

    /// @notice Thrown when liquidity supply amount doesn't match expected
    /// @param amount Provided amount
    /// @param expectedAmount Expected amount
    error SupplyLiquidityWrongInputAmount(uint256 amount, uint256 expectedAmount);

    /// @notice Thrown when collateral amount doesn't match expected
    /// @param amount Provided amount
    /// @param expectedAmount Expected amount
    error CollateralWrongInputAmount(uint256 amount, uint256 expectedAmount);

    /// @notice Thrown when repayment amount doesn't match expected
    /// @param amount Provided amount
    /// @param expectedAmount Expected amount
    error RepayWithSelectedTokenWrongInputAmount(uint256 amount, uint256 expectedAmount);

    /// @notice Thrown when position already exists for user
    /// @param positionAddress Existing position address
    error PositionAlreadyCreated(address positionAddress);

    /// @notice Thrown when input amount is wrong
    /// @param expectedAmount Expected amount
    /// @param actualAmount Actual amount provided
    error WrongInputAmount(uint256 expectedAmount, uint256 actualAmount);

    /// @notice Emitted when user supplies liquidity
    /// @param user User address
    /// @param amount Amount supplied
    /// @param shares Shares received
    event SupplyLiquidity(address user, uint256 amount, uint256 shares);

    /// @notice Emitted when user withdraws liquidity
    /// @param user User address
    /// @param amount Amount withdrawn
    /// @param shares Shares burned
    event WithdrawLiquidity(address user, uint256 amount, uint256 shares);

    /// @notice Emitted when user supplies collateral
    /// @param positionAddress Position contract address
    /// @param user User address
    /// @param amount Amount of collateral supplied
    event SupplyCollateral(address positionAddress, address user, uint256 amount);

    /// @notice Emitted when user repays debt
    /// @param user User address
    /// @param amount Amount repaid
    /// @param shares Shares burned
    event RepayByPosition(address user, uint256 amount, uint256 shares);

    /// @notice Emitted when new position is created
    /// @param user User address
    /// @param positionAddress Position contract address
    event CreatePosition(address user, address positionAddress);

    /// @notice Emitted when user borrows assets
    /// @param user User address
    /// @param amount Amount borrowed
    /// @param shares Borrow shares received
    /// @param chainId Destination chain ID
    /// @param addExecutorLzReceiveOption LayerZero gas option
    event BorrowDebt(address user, uint256 amount, uint256 shares, uint256 chainId, uint256 addExecutorLzReceiveOption);

    /// @notice Emitted when interest rate model is updated
    /// @param oldModel Previous model address
    /// @param newModel New model address
    event InterestRateModelSet(address indexed oldModel, address indexed newModel);

    /// @notice Emitted when user withdraws collateral
    /// @param user User address
    /// @param amount Amount withdrawn
    event WithdrawCollateral(address user, uint256 amount);

    /// @notice Emitted when user swaps tokens in position
    /// @param user User address
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param amountIn Input amount
    /// @param amountOut Output amount
    event SwapTokenByPosition(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /// @notice Emitted when a position is liquidated
    /// @param borrower Borrower address
    /// @param borrowToken Borrow token address
    /// @param collateralToken Collateral token address
    /// @param userBorrowAssets User's borrow assets
    /// @param borrowerCollateral User's collateral
    /// @param liquidationAllocation Liquidation bonus allocation
    /// @param collateralToLiquidator Collateral sent to liquidator
    event Liquidation(
        address borrower,
        address borrowToken,
        address collateralToken,
        uint256 userBorrowAssets,
        uint256 borrowerCollateral,
        uint256 liquidationAllocation,
        uint256 collateralToLiquidator
    );

    /// @notice Address of the lending pool router contract
    address public router;

    /// @dev Track if we're in a withdrawal operation to avoid auto-wrapping
    bool private _withdrawing;

    /**
     * @notice Constructs the LendingPool contract
     * @param _router Address of the lending pool router
     */
    constructor(address _router) {
        router = _router;
    }

    /**
     * @notice Modifier to ensure user has a position contract
     * @param _user User address to check
     * @dev Creates position if it doesn't exist
     */
    modifier positionRequired(address _user) {
        _positionRequired(_user);
        _;
    }

    /**
     * @notice Modifier for access control checks
     * @param _user User address to validate
     * @dev Allows operators or the user themselves
     */
    modifier accessControl(address _user) {
        _accessControl(_user);
        _;
    }

    /**
     * @notice Modifier to check if oracle is set for a token
     * @param _token Token address to check
     * @dev Reverts if oracle is not configured
     */
    modifier checkOracleOnToken(address _token) {
        _checkOracleOnToken(_token);
        _;
    }

    /**
     * @notice Supply liquidity to the lending pool by depositing borrow tokens.
     * @dev Users receive shares proportional to their deposit. Shares represent ownership in the pool. Accrues interest before deposit.
     * @param _user The address of the user to supply liquidity.
     * @param _amount The amount of borrow tokens to supply as liquidity.
     * @custom:emits SupplyLiquidity when liquidity is supplied.
     */
    function supplyLiquidity(address _user, uint256 _amount) public payable nonReentrant accessControl(_user) {
        uint256 shares = _supplyLiquidity(_amount, _user);
        _accrueInterest();
        _supplyLiquidityTransfer(_amount);
        emit SupplyLiquidity(_user, _amount, shares);
    }

    /**
     * @notice Withdraw supplied liquidity by redeeming shares for underlying tokens.
     * @dev Calculates the corresponding asset amount based on the proportion of total shares. Accrues interest before withdrawal.
     * @param _shares The number of supply shares to redeem for underlying tokens.
     * @custom:throws TransferFailed if the transfer fails.
     * @custom:emits WithdrawLiquidity when liquidity is withdrawn.
     */
    function withdrawLiquidity(uint256 _shares) public payable nonReentrant {
        _accrueInterest();
        uint256 amount = _withdrawLiquidity(_shares);
        _withdrawLiquidityTransfer(amount);
        emit WithdrawLiquidity(msg.sender, amount, _shares);
    }

    /**
     * @notice Supply collateral tokens to the user's position in the lending pool.
     * @dev Transfers collateral tokens from user to their Position contract. Accrues interest before deposit.
     * @param _user The address of the user to supply collateral.
     * @param _amount The amount of collateral tokens to supply.
     * @custom:throws ZeroAmount if amount is 0.
     * @custom:emits SupplyCollateral when collateral is supplied.
     */
    function supplyCollateral(address _user, uint256 _amount)
        public
        payable
        positionRequired(_user)
        nonReentrant
        accessControl(_user)
    {
        if (_amount == 0) revert ZeroAmount();
        _accrueInterest();
        _supplyCollateralTransfer(_user, _amount);
        emit SupplyCollateral(_addressPositions(_user), _user, _amount);
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
        _accrueInterest();
        _withdrawCollateralTransfer(_amount);
        if (_userBorrowShares(msg.sender) > 0) {
            IIsHealthy(_isHealthy()).isHealthy(msg.sender, router);
        }

        emit WithdrawCollateral(msg.sender, _amount);
    }

    /**
     * @notice Borrow assets using supplied collateral and optionally send them to a different network.
     * @dev Calculates shares, checks liquidity, and handles cross-chain or local transfers. Accrues interest before borrowing.
     * @param _amount The amount of tokens to borrow.
     * @param _chainId The chain id of the destination network.
     * @custom:throws InsufficientLiquidity if protocol lacks liquidity.
     * @custom:emits BorrowDebt when borrow is successful.
     */
    function borrowDebt(uint256 _amount, uint256 _chainId, uint128 _addExecutorLzReceiveOption)
        public
        payable
        nonReentrant
    {
        _accrueInterest();
        (uint256 protocolFee, uint256 userAmount, uint256 shares) = _borrowDebt(_amount, msg.sender);
        if (_chainId != block.chainid) {
            // LAYERZERO IMPLEMENTATION
            _borrowDebtCrosschain(userAmount, protocolFee, _chainIdToEid(_chainId), _addExecutorLzReceiveOption);
        } else {
            _borrowDebtTransfer(userAmount, protocolFee);
        }
        IIsHealthy(_isHealthy()).isHealthy(msg.sender, router);
        emit BorrowDebt(msg.sender, _amount, shares, _chainId, _addExecutorLzReceiveOption);
    }

    /**
     * @notice Swap tokens within user's position
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _amountIn Amount of input tokens to swap
     * @param _amountOutMinimum Minimum acceptable output amount (slippage protection)
     * @return amountOut Amount of output tokens received
     * @dev Validates oracles for both tokens, checks health after swap
     */
    function swapTokenByPosition(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMinimum)
        public
        positionRequired(msg.sender)
        checkOracleOnToken(_tokenIn)
        checkOracleOnToken(_tokenOut)
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) revert ZeroAmount();
        if (_tokenIn == _tokenOut) {
            revert SwapTokenByPositionInvalidParameter(_tokenIn, _tokenOut);
        }
        _accrueInterest();
        amountOut = IPosition(_addressPositions(msg.sender))
            .swapTokenByPosition(_tokenIn, _tokenOut, _amountIn, _amountOutMinimum);
        IIsHealthy(_isHealthy()).isHealthy(msg.sender, router);
        emit SwapTokenByPosition(msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
    }

    /**
     * @notice Repay borrowed assets using a selected token from the user's position.
     * @dev Swaps selected token to borrow token if needed via position contract. Accrues interest before repayment.
     * @param _user The address of the user to repay the debt.
     * @param _token The address of the token to use for repayment.
     * @param _shares The number of borrow shares to repay.
     * @param _amountOutMinimum The slippage tolerance in basis points (e.g., 500 = 5%).
     * @param _fromPosition Whether to use tokens from the position contract (true) or from the user's wallet (false).
     * @custom:throws ZeroAmount if _shares is 0.
     * @custom:throws amountSharesInvalid if shares exceed user's borrow shares.
     * @custom:emits RepayByPosition when repayment is successful.
     */
    function repayWithSelectedToken(
        address _user,
        address _token,
        uint256 _shares,
        uint256 _amountOutMinimum,
        bool _fromPosition
    ) public payable positionRequired(_user) nonReentrant accessControl(_user) {
        if (_shares == 0) revert ZeroAmount();
        if (_shares > _userBorrowShares(_user)) revert amountSharesInvalid(_shares, _userBorrowShares(_user));
        _accrueInterest();
        (uint256 borrowAmount,,,) = _repayWithSelectedToken(_shares, _user);
        IIsHealthy(_isHealthy()).isHealthy(_user, router);
        _repayWithSelectedTokenTransfer(_user, _token, borrowAmount, _amountOutMinimum, _fromPosition);
        emit RepayByPosition(_user, borrowAmount, _shares);
    }

    /**
     * @notice Liquidates an unhealthy borrower's position
     * @param _borrower The address of the borrower to liquidate
     * @dev Transfers borrow token from liquidator, sends collateral bonus to liquidator
     */
    function liquidation(address _borrower) public nonReentrant {
        (
            uint256 userBorrowAssets,
            uint256 borrowerCollateral,
            uint256 liquidationAllocation,
            uint256 collateralToLiquidator,
            address userPosition
        ) = ILPRouter(router).liquidation(_borrower);

        _isNativeTransferFrom(_borrowToken(), userBorrowAssets);
        // _isNativeTransferTo(msg.sender, _collateralToken(), collateralToLiquidator);
        IPosition(userPosition).liquidation(msg.sender);
        emit Liquidation(
            _borrower,
            _borrowToken(),
            _collateralToken(),
            userBorrowAssets,
            borrowerCollateral,
            liquidationAllocation,
            collateralToLiquidator
        );
    }

    // =============================================================
    //                    INTERNAL HELPER FUNCTIONS
    // =============================================================

    /**
     * @notice Creates a new Position contract for the caller if one does not already exist.
     * @dev Each user can have only one Position contract. The Position contract manages collateral and borrowed assets for the user.
     * @param _user The address of the user to create a position.
     * @custom:throws PositionAlreadyCreated if the caller already has a Position contract.
     * @custom:emits CreatePosition when a new Position is created.
     */
    function _createPosition(address _user) internal {
        if (_addressPositions(_user) != address(0)) revert PositionAlreadyCreated(_addressPositions(_user));
        ILPRouter(router).createPosition(_user);
        emit CreatePosition(_user, _addressPositions(_user));
    }

    /**
     * @notice Internal function to calculate and apply accrued interest to the protocol.
     * @dev Uses dynamic interest rate model based on utilization. Updates total supply and borrow assets and last accrued timestamp.
     */
    function _accrueInterest() internal {
        ILPRouter(router).accrueInterest();
    }

    /**
     * @notice Gets the borrow token address from router
     * @return Address of the borrow token
     */
    function _borrowToken() internal view returns (address) {
        return ILPRouter(router).borrowToken();
    }

    /**
     * @notice Gets the collateral token address from router
     * @return Address of the collateral token
     */
    function _collateralToken() internal view returns (address) {
        return ILPRouter(router).collateralToken();
    }

    /**
     * @notice Gets the loan-to-value ratio from router
     * @return LTV ratio
     */
    function _ltv() internal view returns (uint256) {
        return ILPRouter(router).ltv();
    }

    /**
     * @notice Gets user's borrow shares from router
     * @param _user User address
     * @return User's borrow shares
     */
    function _userBorrowShares(address _user) internal view returns (uint256) {
        return ILPRouter(router).userBorrowShares(_user);
    }

    /**
     * @notice Gets user's position contract address from router
     * @param _user User address
     * @return Address of user's position contract
     */
    function _addressPositions(address _user) internal view returns (address) {
        return ILPRouter(router).addressPositions(_user);
    }

    /**
     * @notice Internal function to supply liquidity via router
     * @param _amount Amount to supply
     * @param _user User address
     * @return Shares minted
     */
    function _supplyLiquidity(uint256 _amount, address _user) internal returns (uint256) {
        return ILPRouter(router).supplyLiquidity(_amount, _user);
    }

    /**
     * @notice Internal function to withdraw liquidity via router
     * @param _shares Shares to burn
     * @return Amount withdrawn
     */
    function _withdrawLiquidity(uint256 _shares) internal returns (uint256) {
        return ILPRouter(router).withdrawLiquidity(_shares, msg.sender);
    }

    /**
     * @notice Internal function to process borrow request via router
     * @param _amount Amount to borrow
     * @param _user User address
     * @return protocolFee Protocol fee amount
     * @return userAmount Amount user receives
     * @return shares Borrow shares minted
     */
    function _borrowDebt(uint256 _amount, address _user) internal returns (uint256, uint256, uint256) {
        return ILPRouter(router).borrowDebt(_amount, _user);
    }

    /**
     * @notice Gets total borrow assets from router
     * @return Total borrow assets
     */
    function _totalBorrowAssets() internal view returns (uint256) {
        return ILPRouter(router).totalBorrowAssets();
    }

    /**
     * @notice Gets total borrow shares from router
     * @return Total borrow shares
     */
    function _totalBorrowShares() internal view returns (uint256) {
        return ILPRouter(router).totalBorrowShares();
    }

    /**
     * @notice Gets factory contract address from router
     * @return Factory address
     */
    function _factory() internal view returns (address) {
        return ILPRouter(router).factory();
    }

    /**
     * @notice Gets protocol address from factory
     * @return Protocol address
     */
    function _protocol() internal view returns (address) {
        return IFactory(_factory()).protocol();
    }

    /**
     * @notice Gets wrapped native token address from factory
     * @return Wrapped native token address
     */
    function _WRAPPED_NATIVE() internal view returns (address) {
        return IFactory(_factory()).WRAPPED_NATIVE();
    }

    /**
     * @notice Gets token data stream address from factory
     * @return Token data stream address
     */
    function _tokenDataStream() internal view returns (address) {
        return IFactory(_factory()).tokenDataStream();
    }

    /**
     * @notice Converts chain ID to LayerZero endpoint ID
     * @param _chainId Chain ID to convert
     * @return LayerZero endpoint ID
     */
    function _chainIdToEid(uint256 _chainId) internal view returns (uint32) {
        return IFactory(_factory()).chainIdToEid(_chainId);
    }

    /**
     * @notice Converts borrow shares to borrow amount
     * @param _shares Shares to convert
     * @return Corresponding borrow amount
     */
    function _shareToAmount(uint256 _shares) internal view returns (uint256) {
        return _shares * _totalBorrowAssets() / _totalBorrowShares();
    }

    /**
     * @notice Converts borrow amount to borrow shares
     * @param _amount Amount to convert
     * @return Corresponding borrow shares
     */
    function _amountToShare(uint256 _amount) internal view returns (uint256) {
        return _amount * _totalBorrowShares() / _totalBorrowAssets();
    }

    // ======================================================================
    /**
     * @notice Checks if oracle is configured for a token
     * @param _token Token address to check
     * @dev Reverts if oracle is not set
     */
    function _checkOracleOnToken(address _token) internal view {
        if (ITokenDataStream(_tokenDataStream()).tokenPriceFeed(_token) == address(0)) {
            revert OracleOnTokenNotSet(_token);
        }
    }

    /**
     * @notice Gets OFT adapter address for borrow token
     * @return OFT adapter address
     */
    function _oftBorrowToken() internal view returns (address) {
        return IFactory(_factory()).oftAddress(_borrowToken());
    }

    /**
     * @notice Internal function to handle liquidity supply token transfer
     * @param _amount Amount to transfer
     * @dev Handles both native and ERC20 tokens
     */
    function _supplyLiquidityTransfer(uint256 _amount) internal {
        if (_borrowToken() == address(1)) {
            if (msg.value != _amount) revert SupplyLiquidityWrongInputAmount(msg.value, _amount);
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: _amount}();
        } else {
            IERC20(_borrowToken()).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    /**
     * @notice Internal function to handle liquidity withdrawal token transfer
     * @param amount Amount to withdraw
     * @dev Handles both native and ERC20 tokens, unwraps native tokens
     */
    function _withdrawLiquidityTransfer(uint256 amount) internal {
        if (_borrowToken() == address(1)) {
            _withdrawing = true;
            IWrappedNative(_WRAPPED_NATIVE()).withdraw(amount);
            (bool sent,) = msg.sender.call{value: amount}("");
            if (!sent) revert TransferFailed(amount);
            _withdrawing = false;
        } else {
            IERC20(_borrowToken()).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Internal function to handle collateral supply token transfer
     * @param _user User address
     * @param _amount Amount to supply
     * @dev Transfers tokens from user to their position contract
     */
    function _supplyCollateralTransfer(address _user, uint256 _amount) internal {
        if (_collateralToken() == address(1)) {
            if (msg.value != _amount) revert CollateralWrongInputAmount(msg.value, _amount);
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
            IERC20(_WRAPPED_NATIVE()).approve(_addressPositions(_user), _amount);
            IERC20(_WRAPPED_NATIVE()).safeTransfer(_addressPositions(_user), _amount);
        } else {
            IERC20(_collateralToken()).safeTransferFrom(_user, _addressPositions(_user), _amount);
        }
    }

    /**
     * @notice Internal function to handle collateral withdrawal token transfer
     * @param _amount Amount to withdraw
     * @dev Withdraws tokens from position contract to user
     */
    function _withdrawCollateralTransfer(uint256 _amount) internal {
        address collateralToken = _collateralToken();
        address tokenToCheck = collateralToken == address(1) ? _WRAPPED_NATIVE() : collateralToken;
        uint256 userCollateralBalance = IERC20(tokenToCheck).balanceOf(_addressPositions(msg.sender));

        if (_amount > userCollateralBalance) {
            revert InsufficientCollateral(_amount, userCollateralBalance);
        }
        _accrueInterest();
        IPosition(_addressPositions(msg.sender)).withdrawCollateral(_amount, msg.sender);
    }

    /**
     * @notice Internal function to handle cross-chain borrow via LayerZero
     * @param _userAmount Amount user receives
     * @param _protocolFee Protocol fee amount
     * @param _dstEid Destination endpoint ID
     * @param _addExecutorLzReceiveOption LayerZero gas option
     * @dev Sends tokens via OFT adapter to destination chain
     */
    function _borrowDebtCrosschain(
        uint256 _userAmount,
        uint256 _protocolFee,
        uint32 _dstEid,
        uint128 _addExecutorLzReceiveOption
    ) internal {
        bytes memory extraOptions =
            OptionsBuilder.newOptions().addExecutorLzReceiveOption(_addExecutorLzReceiveOption, 0);
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: bytes32(uint256(uint160(msg.sender))),
            amountLD: _userAmount,
            minAmountLD: _userAmount, // 0% slippage tolerance
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        IERC20(_borrowToken()).safeTransfer(_protocol(), _protocolFee);
        MessagingFee memory fee = OFTadapter(_oftBorrowToken()).quoteSend(sendParam, false);
        IERC20(_borrowToken()).approve(_oftBorrowToken(), _userAmount);
        OFTadapter(_oftBorrowToken()).send{value: fee.nativeFee}(sendParam, fee, msg.sender);
    }

    /**
     * @notice Internal function to handle local borrow token transfer
     * @param _userAmount Amount to send to user
     * @param _protocolFee Fee amount to send to protocol
     * @dev Handles both native and ERC20 tokens
     */
    function _borrowDebtTransfer(uint256 _userAmount, uint256 _protocolFee) internal {
        if (_borrowToken() == address(1)) {
            _withdrawing = true;
            IWrappedNative(_WRAPPED_NATIVE()).withdraw(_userAmount);
            (bool sent,) = _protocol().call{value: _protocolFee}("");
            if (sent) revert TransferFailed(_protocolFee);
            (bool sent2,) = msg.sender.call{value: _userAmount}("");
            if (sent2) revert TransferFailed(_userAmount);
            _withdrawing = false;
        } else {
            IERC20(_borrowToken()).safeTransfer(_protocol(), _protocolFee);
            IERC20(_borrowToken()).safeTransfer(msg.sender, _userAmount);
        }
    }

    /**
     * @notice Internal function to handle repayment token transfer
     * @param _user User address
     * @param _token Token to use for repayment
     * @param _amount Amount to repay
     * @param _amountOutMinimum Minimum output amount (slippage protection)
     * @param _fromPosition Whether to use tokens from position or wallet
     * @dev Handles token swap if needed and transfers from appropriate source
     */
    function _repayWithSelectedTokenTransfer(
        address _user,
        address _token,
        uint256 _amount,
        uint256 _amountOutMinimum,
        bool _fromPosition
    ) internal {
        if (_token == _borrowToken() && !_fromPosition) {
            if (_borrowToken() == address(1) && msg.value > 0) {
                if (msg.value != _amount) revert RepayWithSelectedTokenWrongInputAmount(msg.value, _amount);
                IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
            } else {
                IERC20(_borrowToken()).safeTransferFrom(_user, address(this), _amount);
            }
        } else if (_fromPosition) {
            IPosition(_addressPositions(_user)).repayWithSelectedToken(_token, _amount, _amountOutMinimum);
        } else {
            // revert("feature unavailable");
            IERC20(_token).safeTransferFrom(_user, address(this), _amount);
            IERC20(_token).approve(_addressPositions(_user), _amount);
            IPosition(_addressPositions(_user)).swapTokenToBorrow(_token, _amount, _amountOutMinimum);
        }
    }
    // ======================================================================

    /**
     * @notice Internal function for access control validation
     * @param _user User address to validate
     * @dev Allows operators or the user themselves
     */
    function _accessControl(address _user) internal view {
        if (!IFactory(_factory()).operator(msg.sender)) {
            if (msg.sender != _user) revert NotAuthorized(msg.sender);
        }
    }

    /**
     * @notice Internal function to ensure user has a position
     * @param _user User address
     * @dev Creates position if it doesn't exist
     */
    function _positionRequired(address _user) internal {
        if (_addressPositions(_user) == address(0)) {
            _createPosition(_user);
        }
    }

    /**
     * @notice Gets the IsHealthy contract address from factory
     * @return IsHealthy contract address
     */
    function _isHealthy() internal view returns (address) {
        return IFactory(_factory()).isHealthy();
    }

    /**
     * @notice Internal function to process repayment with selected token via router
     * @param _shares Shares to repay
     * @param _user User address
     * @return borrowAmount Borrow amount repaid
     * @return protocolFee Protocol fee
     * @return userShares User shares burned
     * @return totalShares Total shares
     */
    function _repayWithSelectedToken(uint256 _shares, address _user)
        internal
        returns (uint256, uint256, uint256, uint256)
    {
        return ILPRouter(router).repayWithSelectedToken(_shares, _user);
    }

    /**
     * @notice Internal function to handle native token transfer from user
     * @param _token Token address (address(1) for native)
     * @param _amount Amount to transfer
     * @dev Wraps native tokens or transfers ERC20
     */
    function _isNativeTransferFrom(address _token, uint256 _amount) internal {
        if (_token == address(1)) {
            if (msg.value != _amount) revert WrongInputAmount(msg.value, _amount);
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    /**
     * @notice Internal function to liquidate position
     * @param _user User address
     * @dev Calls liquidation on user's position contract
     */
    function _liquidToPosition(address _user) internal {
        IPosition(_addressPositions(_user)).liquidation(msg.sender);
    }

    /**
     * @notice Receive function to handle incoming native tokens
     * @dev Auto-wraps native tokens when appropriate, rejects during withdrawals
     */
    receive() external payable {
        // Only auto-wrap if this is the native token lending pool and not during withdrawal
        if (msg.value > 0 && !_withdrawing && (_borrowToken() == address(1) || _collateralToken() == address(1))) {
            IWrappedNative(_WRAPPED_NATIVE()).deposit{value: msg.value}();
        } else if (msg.value > 0 && _withdrawing) {
            // During withdrawal, don't wrap - just pass through
            return;
        } else if (msg.value > 0) {
            // Unexpected native token - revert to prevent loss
            revert("Unexpected native token");
        }
    }

    /**
     * @notice Fallback function to prevent accidental native token loss
     * @dev Always reverts to protect users
     */
    fallback() external payable {
        // Fallback should not accept native tokens to prevent accidental loss
        revert("Fallback not allowed");
    }
}
