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
 * @author Senja Protocol
 * @notice Factory contract for creating and managing lending pools
 * @dev This contract serves as the main entry point for creating new lending pools.
 * It maintains a registry of all created pools and manages token data streams
 * and cross-chain token senders.
 */
contract LendingPoolFactory is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

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

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
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
     * @notice Emitted when an operator is set
     * @param operator The address of the operator
     * @param status The status of the operator
     */
    event OperatorSet(address indexed operator, bool status);

    /**
     * @notice Emitted when an oft address is set
     * @param token The address of the token
     * @param oftAddress The address of the oft address
     */
    event OftAddressSet(address indexed token, address indexed oftAddress);

    event TokenDataStreamSet(address indexed tokenDataStream);

    event LendingPoolDeployerSet(address indexed lendingPoolDeployer);

    event ProtocolSet(address indexed protocol);

    event IsHealthySet(address indexed isHealthy);

    event PositionDeployerSet(address indexed positionDeployer);

    event LendingPoolRouterDeployerSet(address indexed lendingPoolRouterDeployer);

    event WrappedNativeSet(address indexed wrappedNative);

    event DexRouterSet(address indexed dexRouter);

    event MinAmountSupplyLiquiditySet(address indexed token, uint256 indexed minAmountSupplyLiquidity);

    event InterestRateModelSet(address indexed interestRateModel);

    error OracleOnTokenNotSet(address token);
    error MinAmountSupplyLiquidityExceeded(uint256 amount, uint256 minAmountSupplyLiquidity);

    /// @notice The address of the IsHealthy contract for health checks
    address public isHealthy;

    /// @notice The address of the lending pool deployer contract
    address public lendingPoolDeployer;

    /// @notice The address of the protocol contract
    address public protocol;

    address public positionDeployer;

    address public WRAPPED_NATIVE;

    address public DEX_ROUTER;

    address public lendingPoolRouterDeployer;

    address public tokenDataStream;

    address public interestRateModel;

    mapping(address => bool) public operator;

    mapping(address => address) public oftAddress; // token => oftaddress

    mapping(address => uint256) public minAmountSupplyLiquidity; // token => amount
    mapping(uint256 => uint32) public chainIdToEid; // chainId => eid

    /// @notice Total number of pools created
    uint256 public poolCount;

    modifier checkOracleOnToken(address _token) {
        _checkOracleOnToken(_token);
        _;
    }

    modifier checkMinAmountSupplyLiquidity(address _borrowToken, uint256 _supplyLiquidity) {
        _checkMinAmountSupplyLiquidity(_borrowToken, _supplyLiquidity);
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

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
     * @param _lendingPoolParams The parameters for the lending pool
     * @dev This function deploys a new lending pool using the lending pool deployer
     * @return The address of the newly created lending pool
     * @dev This function deploys a new lending pool using the lending pool deployer
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
     * @notice Adds a token data stream for price feeds and other data
     * @param _tokenDataStream The address of the data stream contract
     * @dev Only callable by the owner
     */
    function setTokenDataStream(address _tokenDataStream) public onlyRole(OWNER_ROLE) {
        tokenDataStream = _tokenDataStream;
        emit TokenDataStreamSet(_tokenDataStream);
    }

    function setOperator(address _operator, bool _status) public onlyRole(OWNER_ROLE) {
        operator[_operator] = _status;
        emit OperatorSet(_operator, _status);
    }

    function setOftAddress(address _token, address _oftAddress) public onlyRole(OWNER_ROLE) {
        oftAddress[_token] = _oftAddress;
        emit OftAddressSet(_token, _oftAddress);
    }

    function setLendingPoolDeployer(address _lendingPoolDeployer) public onlyRole(OWNER_ROLE) {
        lendingPoolDeployer = _lendingPoolDeployer;
        emit LendingPoolDeployerSet(_lendingPoolDeployer);
    }

    function setProtocol(address _protocol) public onlyRole(OWNER_ROLE) {
        protocol = _protocol;
        emit ProtocolSet(_protocol);
    }

    function setIsHealthy(address _isHealthy) public onlyRole(OWNER_ROLE) {
        isHealthy = _isHealthy;
        emit IsHealthySet(_isHealthy);
    }

    function setPositionDeployer(address _positionDeployer) public onlyRole(OWNER_ROLE) {
        positionDeployer = _positionDeployer;
        emit PositionDeployerSet(_positionDeployer);
    }

    function setLendingPoolRouterDeployer(address _lendingPoolRouterDeployer) public onlyRole(OWNER_ROLE) {
        lendingPoolRouterDeployer = _lendingPoolRouterDeployer;
        emit LendingPoolRouterDeployerSet(_lendingPoolRouterDeployer);
    }

    function setWrappedNative(address _wrappedNative) public onlyRole(OWNER_ROLE) {
        WRAPPED_NATIVE = _wrappedNative;
        emit WrappedNativeSet(_wrappedNative);
    }

    function setDexRouter(address _dexRouter) public onlyRole(OWNER_ROLE) {
        DEX_ROUTER = _dexRouter;
        emit DexRouterSet(_dexRouter);
    }

    function setMinAmountSupplyLiquidity(address _token, uint256 _minAmountSupplyLiquidity)
        public
        onlyRole(OWNER_ROLE)
    {
        minAmountSupplyLiquidity[_token] = _minAmountSupplyLiquidity;
        emit MinAmountSupplyLiquiditySet(_token, _minAmountSupplyLiquidity);
    }

    function setInterestRateModel(address _interestRateModel) public onlyRole(OWNER_ROLE) {
        interestRateModel = _interestRateModel;
        emit InterestRateModelSet(_interestRateModel);
    }

    function _checkOracleOnToken(address _token) internal view {
        if (tokenDataStream == address(0)) revert OracleOnTokenNotSet(_token);
    }

    function _checkMinAmountSupplyLiquidity(address _borrowToken, uint256 _supplyLiquidity) internal view {
        if (_supplyLiquidity < minAmountSupplyLiquidity[_borrowToken] || minAmountSupplyLiquidity[_borrowToken] == 0) {
            revert MinAmountSupplyLiquidityExceeded(_supplyLiquidity, minAmountSupplyLiquidity[_borrowToken]);
        }
    }
    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation The address of the new implementation
     * @dev Only callable by addresses with UPGRADER_ROLE
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Fallback function to handle calls with empty data during upgrades
     * @dev This is needed for compatibility with older OpenZeppelin versions
     */
    fallback() external {}
}
