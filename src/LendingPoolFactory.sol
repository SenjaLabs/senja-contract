// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ILPDeployer} from "./interfaces/ILPDeployer.sol";
import {ILPRouterDeployer} from "./interfaces/ILPRouterDeployer.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {ILPRouter} from "./interfaces/ILPRouter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {IIsHealthy} from "./interfaces/IIsHealthy.sol";

/**
 * @title LendingPoolFactory
 * @author Senja Labs
 * @notice Factory contract for creating and managing lending pools
 * @dev This contract serves as the main entry point for creating new lending pools.
 * It maintains a registry of all created pools and manages token data streams,
 * cross-chain token senders, and various protocol configurations. The contract is
 * upgradeable using the UUPS pattern and includes pausable functionality for emergency stops.
 */
contract LendingPoolFactory is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    /**
     * @notice Parameters required for creating a new lending pool
     * @dev This struct encapsulates all configuration parameters needed to deploy a lending pool
     * @param collateralToken The address of the token used as collateral
     * @param borrowToken The address of the token that can be borrowed
     * @param ltv The Loan-to-Value ratio (e.g., 8000 for 80%)
     * @param supplyLiquidity The initial amount of borrow tokens to supply to the pool
     * @param baseRate The base interest rate when utilization is 0
     * @param rateAtOptimal The interest rate at optimal utilization
     * @param optimalUtilization The target utilization rate for the pool
     * @param maxUtilization The maximum allowed utilization rate
     * @param liquidationThreshold The threshold at which positions become liquidatable
     * @param liquidationBonus The bonus awarded to liquidators
     */
    struct LendingPoolParams {
        address collateralToken;
        address borrowToken;
        uint256 ltv;
        uint256 supplyLiquidity;
        uint256 baseRate;
        uint256 rateAtOptimal;
        uint256 optimalUtilization;
        uint256 maxUtilization;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
    }

    /// @notice Role identifier for addresses that can pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role identifier for addresses that can upgrade the contract implementation
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role identifier for addresses that have owner privileges
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /**
     * @notice Emitted when a new lending pool is created
     * @param collateralToken The address of the collateral token
     * @param borrowToken The address of the borrow token
     * @param lendingPool The address of the created lending pool
     * @param ltv The Loan-to-Value ratio for the pool
     */
    event LendingPoolCreated(
        address indexed collateralToken, address indexed borrowToken, address indexed lendingPool, uint256 ltv
    );

    /**
     * @notice Emitted when an operator status is updated
     * @param operator The address of the operator
     * @param status The new status of the operator (true for active, false for inactive)
     */
    event OperatorSet(address indexed operator, bool status);

    /**
     * @notice Emitted when an OFT (Omnichain Fungible Token) address is set for a token
     * @param token The address of the token
     * @param oftAddress The address of the OFT wrapper for cross-chain transfers
     */
    event OftAddressSet(address indexed token, address indexed oftAddress);

    /**
     * @notice Emitted when the token data stream address is updated
     * @param tokenDataStream The address of the new token data stream contract
     */
    event TokenDataStreamSet(address indexed tokenDataStream);

    /**
     * @notice Emitted when the lending pool deployer address is updated
     * @param lendingPoolDeployer The address of the new lending pool deployer contract
     */
    event LendingPoolDeployerSet(address indexed lendingPoolDeployer);

    /**
     * @notice Emitted when the protocol address is updated
     * @param protocol The address of the new protocol contract
     */
    event ProtocolSet(address indexed protocol);

    /**
     * @notice Emitted when the IsHealthy contract address is updated
     * @param isHealthy The address of the new IsHealthy contract
     */
    event IsHealthySet(address indexed isHealthy);

    /**
     * @notice Emitted when the position deployer address is updated
     * @param positionDeployer The address of the new position deployer contract
     */
    event PositionDeployerSet(address indexed positionDeployer);

    /**
     * @notice Emitted when the lending pool router deployer address is updated
     * @param lendingPoolRouterDeployer The address of the new router deployer contract
     */
    event LendingPoolRouterDeployerSet(address indexed lendingPoolRouterDeployer);

    /**
     * @notice Emitted when the wrapped native token address is updated
     * @param wrappedNative The address of the new wrapped native token
     */
    event WrappedNativeSet(address indexed wrappedNative);

    /**
     * @notice Emitted when the DEX router address is updated
     * @param dexRouter The address of the new DEX router
     */
    event DexRouterSet(address indexed dexRouter);

    /**
     * @notice Emitted when the minimum supply liquidity amount is set for a token
     * @param token The address of the token
     * @param minAmountSupplyLiquidity The minimum amount required for initial liquidity supply
     */
    event MinAmountSupplyLiquiditySet(address indexed token, uint256 indexed minAmountSupplyLiquidity);

    /**
     * @notice Emitted when the interest rate model address is updated
     * @param interestRateModel The address of the new interest rate model contract
     */
    event InterestRateModelSet(address indexed interestRateModel);

    /**
     * @notice Emitted when a chain ID to endpoint ID mapping is set
     * @param chainId The blockchain chain ID
     * @param eid The LayerZero endpoint ID
     */
    event ChainIdToEidSet(uint256 indexed chainId, uint32 indexed eid);

    /**
     * @notice Thrown when attempting to use a token without a configured oracle
     * @param token The address of the token missing an oracle configuration
     */
    error OracleOnTokenNotSet(address token);

    /**
     * @notice Thrown when the supplied liquidity is below the minimum required amount
     * @param amount The amount of liquidity provided
     * @param minAmountSupplyLiquidity The minimum required liquidity amount
     */
    error MinAmountSupplyLiquidityExceeded(uint256 amount, uint256 minAmountSupplyLiquidity);

    /// @notice The address of the IsHealthy contract for position health checks
    address public isHealthy;

    /// @notice The address of the lending pool deployer contract
    address public lendingPoolDeployer;

    /// @notice The address of the protocol contract
    address public protocol;

    /// @notice The address of the position deployer contract
    address public positionDeployer;

    /// @notice The address of the wrapped native token (e.g., WETH, WMATIC)
    address public wrappedNative;

    /// @notice The address of the DEX router for token swaps
    address public dexRouter;

    /// @notice The address of the lending pool router deployer contract
    address public lendingPoolRouterDeployer;

    /// @notice The address of the token data stream contract for price feeds
    address public tokenDataStream;

    /// @notice The address of the interest rate model contract
    address public interestRateModel;

    /// @notice Mapping of operator addresses to their active status
    mapping(address => bool) public operator;

    /// @notice Mapping of token addresses to their OFT (Omnichain Fungible Token) addresses
    mapping(address => address) public oftAddress;

    /// @notice Mapping of token addresses to their minimum initial supply liquidity requirements
    mapping(address => uint256) public minAmountSupplyLiquidity;

    /// @notice Mapping of blockchain chain IDs to LayerZero endpoint IDs
    mapping(uint256 => uint32) public chainIdToEid;

    /**
     * @notice Modifier to check if a token has an oracle configured
     * @param _token The address of the token to check
     */
    modifier checkOracleOnToken(address _token) {
        _checkOracleOnToken(_token);
        _;
    }

    /**
     * @notice Modifier to check if the supplied liquidity meets the minimum requirement
     * @param _borrowToken The address of the borrow token
     * @param _supplyLiquidity The amount of liquidity being supplied
     */
    modifier checkMinAmountSupplyLiquidity(address _borrowToken, uint256 _supplyLiquidity) {
        _checkMinAmountSupplyLiquidity(_borrowToken, _supplyLiquidity);
        _;
    }

    /**
     * @notice Constructor that disables initializers to prevent implementation contract initialization
     * @dev This is a security measure for UUPS upgradeable contracts
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Pauses all contract operations
     * @dev Can only be called by addresses with PAUSER_ROLE
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all contract operations
     * @dev Can only be called by addresses with PAUSER_ROLE
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Initializes the contract with required addresses and roles
     * @dev This function can only be called once due to the initializer modifier
     * @param _isHealthy The address of the IsHealthy contract
     * @param _lendingPoolRouterDeployer The address of the router deployer contract
     * @param _lendingPoolDeployer The address of the lending pool deployer contract
     * @param _protocol The address of the protocol contract
     * @param _positionDeployer The address of the position deployer contract
     */
    function initialize(
        address _isHealthy,
        address _lendingPoolRouterDeployer,
        address _lendingPoolDeployer,
        address _protocol,
        address _positionDeployer
    ) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);

        isHealthy = _isHealthy;
        lendingPoolRouterDeployer = _lendingPoolRouterDeployer;
        lendingPoolDeployer = _lendingPoolDeployer;
        protocol = _protocol;
        positionDeployer = _positionDeployer;
    }

    /**
     * @notice Creates a new lending pool with the specified parameters
     * @dev Deploys both a router and lending pool, configures interest rate model and liquidation parameters,
     * and supplies initial liquidity. Requires caller to have approved sufficient borrow tokens.
     * @param _lendingPoolParams The parameters for the lending pool including tokens, rates, and thresholds
     * @return The address of the newly created lending pool
     */
    function createLendingPool(LendingPoolParams memory _lendingPoolParams)
        public
        checkOracleOnToken(_lendingPoolParams.collateralToken)
        checkOracleOnToken(_lendingPoolParams.borrowToken)
        checkMinAmountSupplyLiquidity(_lendingPoolParams.borrowToken, _lendingPoolParams.supplyLiquidity)
        returns (address)
    {
        // Deploy a new router for this pool
        address router = ILPRouterDeployer(lendingPoolRouterDeployer)
            .deployLendingPoolRouter(
                address(this),
                _lendingPoolParams.collateralToken,
                _lendingPoolParams.borrowToken,
                _lendingPoolParams.ltv
            );
        // Deploy the LendingPool
        address lendingPool = ILPDeployer(lendingPoolDeployer).deployLendingPool(address(router));
        IInterestRateModel(interestRateModel).setLendingPoolBaseRate(router, _lendingPoolParams.baseRate);
        IInterestRateModel(interestRateModel).setLendingPoolRateAtOptimal(router, _lendingPoolParams.rateAtOptimal);
        IInterestRateModel(interestRateModel)
            .setLendingPoolOptimalUtilization(router, _lendingPoolParams.optimalUtilization);
        IInterestRateModel(interestRateModel).setLendingPoolMaxUtilization(router, _lendingPoolParams.maxUtilization);

        IIsHealthy(isHealthy).setLiquidationThreshold(router, _lendingPoolParams.liquidationThreshold);
        IIsHealthy(isHealthy).setLiquidationBonus(router, _lendingPoolParams.liquidationBonus);
        // Configure the lending pool address in the router
        ILPRouter(router).setLendingPool(lendingPool);
        IERC20(_lendingPoolParams.borrowToken)
            .safeTransferFrom(msg.sender, address(this), _lendingPoolParams.supplyLiquidity);
        IERC20(_lendingPoolParams.borrowToken).approve(lendingPool, _lendingPoolParams.supplyLiquidity);
        ILendingPool(lendingPool).supplyLiquidity(msg.sender, _lendingPoolParams.supplyLiquidity);
        emit LendingPoolCreated(
            _lendingPoolParams.collateralToken,
            _lendingPoolParams.borrowToken,
            address(lendingPool),
            _lendingPoolParams.ltv
        );
        return address(lendingPool);
    }

    /**
     * @notice Sets the token data stream contract address for price feeds
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _tokenDataStream The address of the data stream contract
     */
    function setTokenDataStream(address _tokenDataStream) public onlyRole(OWNER_ROLE) {
        tokenDataStream = _tokenDataStream;
        emit TokenDataStreamSet(_tokenDataStream);
    }

    /**
     * @notice Sets or updates the status of an operator
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _operator The address of the operator to update
     * @param _status The new status for the operator (true for active, false for inactive)
     */
    function setOperator(address _operator, bool _status) public onlyRole(OWNER_ROLE) {
        operator[_operator] = _status;
        emit OperatorSet(_operator, _status);
    }

    /**
     * @notice Sets the OFT (Omnichain Fungible Token) address for a specific token
     * @dev Only callable by addresses with OWNER_ROLE. Used for cross-chain token transfers.
     * @param _token The address of the token
     * @param _oftAddress The address of the corresponding OFT wrapper
     */
    function setOftAddress(address _token, address _oftAddress) public onlyRole(OWNER_ROLE) {
        oftAddress[_token] = _oftAddress;
        emit OftAddressSet(_token, _oftAddress);
    }

    /**
     * @notice Sets the lending pool deployer contract address
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _lendingPoolDeployer The address of the new lending pool deployer
     */
    function setLendingPoolDeployer(address _lendingPoolDeployer) public onlyRole(OWNER_ROLE) {
        lendingPoolDeployer = _lendingPoolDeployer;
        emit LendingPoolDeployerSet(_lendingPoolDeployer);
    }

    /**
     * @notice Sets the protocol contract address
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _protocol The address of the new protocol contract
     */
    function setProtocol(address _protocol) public onlyRole(OWNER_ROLE) {
        protocol = _protocol;
        emit ProtocolSet(_protocol);
    }

    /**
     * @notice Sets the IsHealthy contract address for position health checks
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _isHealthy The address of the new IsHealthy contract
     */
    function setIsHealthy(address _isHealthy) public onlyRole(OWNER_ROLE) {
        isHealthy = _isHealthy;
        emit IsHealthySet(_isHealthy);
    }

    /**
     * @notice Sets the position deployer contract address
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _positionDeployer The address of the new position deployer contract
     */
    function setPositionDeployer(address _positionDeployer) public onlyRole(OWNER_ROLE) {
        positionDeployer = _positionDeployer;
        emit PositionDeployerSet(_positionDeployer);
    }

    /**
     * @notice Sets the lending pool router deployer contract address
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _lendingPoolRouterDeployer The address of the new router deployer contract
     */
    function setLendingPoolRouterDeployer(address _lendingPoolRouterDeployer) public onlyRole(OWNER_ROLE) {
        lendingPoolRouterDeployer = _lendingPoolRouterDeployer;
        emit LendingPoolRouterDeployerSet(_lendingPoolRouterDeployer);
    }

    /**
     * @notice Sets the wrapped native token address
     * @dev Only callable by addresses with OWNER_ROLE. Examples: WETH, WMATIC, etc.
     * @param _wrappedNative The address of the wrapped native token
     */
    function setWrappedNative(address _wrappedNative) public onlyRole(OWNER_ROLE) {
        wrappedNative = _wrappedNative;
        emit WrappedNativeSet(_wrappedNative);
    }

    /**
     * @notice Sets the DEX router address for token swaps
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _dexRouter The address of the DEX router contract
     */
    function setDexRouter(address _dexRouter) public onlyRole(OWNER_ROLE) {
        dexRouter = _dexRouter;
        emit DexRouterSet(_dexRouter);
    }

    /**
     * @notice Sets the minimum initial supply liquidity requirement for a token
     * @dev Only callable by addresses with OWNER_ROLE. This ensures pools have sufficient liquidity at creation.
     * @param _token The address of the token
     * @param _minAmountSupplyLiquidity The minimum amount of tokens required for initial liquidity
     */
    function setMinAmountSupplyLiquidity(address _token, uint256 _minAmountSupplyLiquidity)
        public
        onlyRole(OWNER_ROLE)
    {
        minAmountSupplyLiquidity[_token] = _minAmountSupplyLiquidity;
        emit MinAmountSupplyLiquiditySet(_token, _minAmountSupplyLiquidity);
    }

    /**
     * @notice Sets the interest rate model contract address
     * @dev Only callable by addresses with OWNER_ROLE
     * @param _interestRateModel The address of the new interest rate model contract
     */
    function setInterestRateModel(address _interestRateModel) public onlyRole(OWNER_ROLE) {
        interestRateModel = _interestRateModel;
        emit InterestRateModelSet(_interestRateModel);
    }

    /**
     * @notice Sets the LayerZero endpoint ID for a specific chain ID
     * @dev Only callable by addresses with OWNER_ROLE. Used for cross-chain messaging.
     * @param _chainId The blockchain chain ID
     * @param _eid The LayerZero endpoint ID corresponding to the chain
     */
    function setChainIdToEid(uint256 _chainId, uint32 _eid) public onlyRole(OWNER_ROLE) {
        chainIdToEid[_chainId] = _eid;
        emit ChainIdToEidSet(_chainId, _eid);
    }

    /**
     * @notice Internal function to verify that a token has an oracle configured
     * @dev Reverts if the tokenDataStream is not set
     * @param _token The address of the token to check
     */
    function _checkOracleOnToken(address _token) internal view {
        if (tokenDataStream == address(0)) revert OracleOnTokenNotSet(_token);
    }

    /**
     * @notice Internal function to verify that supplied liquidity meets the minimum requirement
     * @dev Reverts if the supplied amount is less than the minimum or if minimum is not set
     * @param _borrowToken The address of the borrow token
     * @param _supplyLiquidity The amount of liquidity being supplied
     */
    function _checkMinAmountSupplyLiquidity(address _borrowToken, uint256 _supplyLiquidity) internal view {
        if (_supplyLiquidity < minAmountSupplyLiquidity[_borrowToken] || minAmountSupplyLiquidity[_borrowToken] == 0) {
            revert MinAmountSupplyLiquidityExceeded(_supplyLiquidity, minAmountSupplyLiquidity[_borrowToken]);
        }
    }

    /**
     * @notice Authorizes contract upgrades
     * @dev Only callable by addresses with UPGRADER_ROLE. Part of the UUPS upgrade pattern.
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Fallback function to handle calls with empty data during upgrades
     * @dev This is needed for compatibility with UUPS upgrade mechanism
     */
    fallback() external {}
}
