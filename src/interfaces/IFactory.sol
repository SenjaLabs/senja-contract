// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IFactory
 * @dev Interface for lending pool factory functionality
 * @notice This interface defines the contract for creating and managing lending pools
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IFactory {
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

    function tokenDataStream() external view returns (address);

    function positionDeployer() external view returns (address);

    /**
     * @dev Returns the owner address of the factory
     * @return Address of the factory owner
     */
    function owner() external view returns (address);

    /**
     * @dev Returns the address of the health check contract
     * @return Address of the isHealthy contract
     */
    function isHealthy() external view returns (address);

    function operator(address _operator) external view returns (bool);

    function oftAddress(address _token) external view returns (address);

    function WRAPPED_NATIVE() external view returns (address);

    /**
     * @dev Adds a token data stream to the factory
     * @param _tokenDataStream Address of the token data stream contract
     * @notice This function registers a new token data stream
     * @custom:security Only the owner should be able to add data streams
     */
    function setTokenDataStream(address _tokenDataStream) external;

    /**
     * @dev Creates a new lending pool
     * @param _lendingPoolParams The parameters for the lending pool
     * @return Address of the newly created lending pool
     * @notice This function deploys a new lending pool with specified parameters
     * @custom:security Only authorized addresses should be able to create pools
     */
    function createLendingPool(LendingPoolParams memory _lendingPoolParams) external returns (address);

    function setOperator(address _operator, bool _status) external;

    function setInterestRateModel(address _interestRateModel) external;

    function setMinAmountSupplyLiquidity(address _token, uint256 _minAmountSupplyLiquidity) external;

    /**
     * @dev Returns the protocol contract address
     * @return Address of the protocol contract
     */
    function protocol() external view returns (address);

    /**
     * @dev Returns the total number of pools created
     * @return Number of lending pools created by this factory
     */
    function poolCount() external view returns (uint256);

    function setOftAddress(address _token, address _oftAddress) external;

    function setPositionDeployer(address _positionDeployer) external;

    function setWrappedNative(address _wrappedNative) external;

    function setDexRouter(address _dexRouter) external;

    function DEX_ROUTER() external view returns (address);

    function interestRateModel() external view returns (address);

    function chainIdToEid(uint256 _chainId) external view returns (uint32);
}
