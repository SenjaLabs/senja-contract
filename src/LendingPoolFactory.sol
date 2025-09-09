// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ILPDeployer} from "./interfaces/ILPDeployer.sol";
import {InterestRateModel} from "./InterestRateModel.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title LendingPoolFactory
 * @author Ibran Protocol
 * @notice Factory contract for creating and managing lending pools
 * @dev This contract serves as the main entry point for creating new lending pools.
 * It maintains a registry of all created pools and manages token data streams
 * and cross-chain token senders.
 */
contract LendingPoolFactory {
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

    /**
     * @notice Emitted when an interest rate model is deployed
     * @param lendingPool The address of the lending pool
     * @param interestRateModel The address of the interest rate model
     */
    event InterestRateModelDeployed(address indexed lendingPool, address indexed interestRateModel);

    /**
     * @notice Emitted when a token data stream is added
     * @param token The address of the token
     * @param dataStream The address of the data stream contract
     */
    event TokenDataStreamAdded(address indexed token, address indexed dataStream);

    /**
     * @notice Structure representing a lending pool
     * @param collateralToken The address of the collateral token
     * @param borrowToken The address of the borrow token
     * @param lendingPoolAddress The address of the lending pool contract
     */
    // solhint-disable-next-line gas-struct-packing
    struct Pool {
        address collateralToken;
        address borrowToken;
        address lendingPoolAddress;
    }

    /// @notice The owner of the factory contract
    address public owner;

    /// @notice The address of the IsHealthy contract for health checks
    address public isHealthy;

    /// @notice The address of the lending pool deployer contract
    address public lendingPoolDeployer;

    /// @notice The address of the protocol contract
    address public protocol;

    /// @notice Mapping from token address to its data stream address
    mapping(address => address) public tokenDataStream;
    
    /// @notice Mapping from lending pool to its interest rate model
    mapping(address => address) public poolInterestRateModel;

    mapping(address => bool) public operator;

    mapping(address => address) public oftAddress; // token => oftaddress

    /// @notice Array of all created pools
    Pool[] public pools;

    /// @notice Total number of pools created
    uint256 public poolCount;

    /**
     * @notice Constructor for the LendingPoolFactory
     * @param _isHealthy The address of the IsHealthy contract
     * @param _lendingPoolDeployer The address of the lending pool deployer contract
     */
    constructor(address _isHealthy, address _lendingPoolDeployer, address _protocol) {
        owner = msg.sender;
        isHealthy = _isHealthy;
        lendingPoolDeployer = _lendingPoolDeployer;
        protocol = _protocol;
    }

    /**
     * @notice Modifier to restrict function access to the owner only
     */
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        require(msg.sender == owner, "Only owner can call this function");
    }

    /**
     * @notice Creates a new lending pool with the specified parameters
     * @param collateralToken The address of the collateral token
     * @param borrowToken The address of the borrow token
     * @param ltv The Loan-to-Value ratio for the pool (in basis points)
     * @return The address of the newly created lending pool
     * @dev This function deploys a new lending pool using the lending pool deployer
     * and adds it to the pools registry. It also deploys a dedicated InterestRateModel
     * and configures the lending pool address in the InterestRateModel.
     */
    function createLendingPool(address collateralToken, address borrowToken, uint256 ltv) public returns (address) {
        // Deploy a new InterestRateModel for this pool
        InterestRateModel interestRateModel = new InterestRateModel(owner);
        
        // Deploy the LendingPool with the InterestRateModel
        address lendingPool = ILPDeployer(lendingPoolDeployer).deployLendingPool(collateralToken, borrowToken, ltv, address(interestRateModel));
        
        // Configure the lending pool address in the InterestRateModel
        // This allows only the lending pool to update its own interest rate parameters
        IInterestRateModel(address(interestRateModel)).setLendingPool(lendingPool);
        
        // Store the relationship
        poolInterestRateModel[lendingPool] = address(interestRateModel);
        
        pools.push(Pool(collateralToken, borrowToken, address(lendingPool)));
        poolCount++;
        
        emit LendingPoolCreated(collateralToken, borrowToken, address(lendingPool), ltv);
        emit InterestRateModelDeployed(lendingPool, address(interestRateModel));
        
        return address(lendingPool);
    }

    /**
     * @notice Adds a token data stream for price feeds and other data
     * @param _token The address of the token
     * @param _dataStream The address of the data stream contract
     * @dev Only callable by the owner
     */
    function addTokenDataStream(address _token, address _dataStream) public onlyOwner {
        tokenDataStream[_token] = _dataStream;
        emit TokenDataStreamAdded(_token, _dataStream);
    }

    function setOperator(address _operator, bool _status) public onlyOwner {
        operator[_operator] = _status;
        emit OperatorSet(_operator, _status);
    }

    function setOftAddress(address _token, address _oftAddress) public onlyOwner {
        oftAddress[_token] = _oftAddress;
        emit OftAddressSet(_token, _oftAddress);
    }

    /**
     * @notice Get the interest rate model address for a specific lending pool
     * @param _lendingPool The address of the lending pool
     * @return The address of the interest rate model
     */
    function getInterestRateModel(address _lendingPool) public view returns (address) {
        return poolInterestRateModel[_lendingPool];
    }
}
