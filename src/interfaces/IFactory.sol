// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IFactory
 * @notice Interface for lending pool factory functionality
 * @dev Defines the contract for creating and managing lending pools
 * @author Senja Team
 * @custom:version 1.0.0
 */
interface IFactory {
    /**
     * @notice Struct containing parameters for lending pool creation
     * @param collateralToken Address of the collateral token
     * @param borrowToken Address of the borrow token
     * @param ltv Loan-to-value ratio (in basis points)
     * @param supplyLiquidity Initial liquidity to supply
     * @param baseRate Base interest rate when utilization is 0
     * @param rateAtOptimal Interest rate at optimal utilization
     * @param optimalUtilization Target utilization rate (in basis points)
     * @param maxUtilization Maximum utilization rate allowed (in basis points)
     * @param liquidationThreshold Threshold at which positions can be liquidated
     * @param liquidationBonus Bonus given to liquidators (in basis points)
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

    /**
     * @notice Returns the address of the token data stream contract
     * @return Address of the token data stream
     */
    function tokenDataStream() external view returns (address);

    /**
     * @notice Returns the address of the position deployer contract
     * @return Address of the position deployer
     */
    function positionDeployer() external view returns (address);

    /**
     * @notice Returns the owner address of the factory
     * @return Address of the factory owner
     */
    function owner() external view returns (address);

    /**
     * @notice Returns the address of the health check contract
     * @return Address of the isHealthy contract
     */
    function isHealthy() external view returns (address);

    /**
     * @notice Checks if an address is an authorized operator
     * @param _operator Address to check
     * @return True if the address is an operator
     */
    function operator(address _operator) external view returns (bool);

    /**
     * @notice Returns the OFT (Omnichain Fungible Token) address for a token
     * @param _token Address of the token
     * @return Address of the OFT contract
     */
    function oftAddress(address _token) external view returns (address);

    /**
     * @notice Returns the address of the wrapped native token
     * @return Address of the wrapped native token contract
     */
    function WRAPPED_NATIVE() external view returns (address);

    /**
     * @notice Sets the token data stream contract address
     * @param _tokenDataStream Address of the token data stream contract
     */
    function setTokenDataStream(address _tokenDataStream) external;

    /**
     * @notice Creates a new lending pool
     * @param _lendingPoolParams The parameters for the lending pool
     * @return Address of the newly created lending pool router
     */
    function createLendingPool(LendingPoolParams memory _lendingPoolParams) external returns (address);

    /**
     * @notice Sets operator status for an address
     * @param _operator Address of the operator
     * @param _status True to grant operator status, false to revoke
     */
    function setOperator(address _operator, bool _status) external;

    /**
     * @notice Sets the interest rate model contract address
     * @param _interestRateModel Address of the interest rate model
     */
    function setInterestRateModel(address _interestRateModel) external;

    /**
     * @notice Sets the minimum amount required to supply liquidity for a token
     * @param _token Address of the token
     * @param _minAmountSupplyLiquidity Minimum amount required
     */
    function setMinAmountSupplyLiquidity(address _token, uint256 _minAmountSupplyLiquidity) external;

    /**
     * @notice Returns the protocol contract address
     * @return Address of the protocol contract
     */
    function protocol() external view returns (address);

    /**
     * @notice Returns the total number of pools created
     * @return Number of lending pools created by this factory
     */
    function poolCount() external view returns (uint256);

    /**
     * @notice Sets the OFT address for a token
     * @param _token Address of the token
     * @param _oftAddress Address of the OFT contract
     */
    function setOftAddress(address _token, address _oftAddress) external;

    /**
     * @notice Sets the position deployer contract address
     * @param _positionDeployer Address of the position deployer
     */
    function setPositionDeployer(address _positionDeployer) external;

    /**
     * @notice Sets the wrapped native token contract address
     * @param _wrappedNative Address of the wrapped native token
     */
    function setWrappedNative(address _wrappedNative) external;

    /**
     * @notice Sets the DEX router contract address
     * @param _dexRouter Address of the DEX router
     */
    function setDexRouter(address _dexRouter) external;

    /**
     * @notice Returns the address of the DEX router
     * @return Address of the DEX router contract
     */
    function DEX_ROUTER() external view returns (address);

    /**
     * @notice Returns the address of the interest rate model
     * @return Address of the interest rate model contract
     */
    function interestRateModel() external view returns (address);

    /**
     * @notice Converts a chain ID to LayerZero endpoint ID
     * @param _chainId The chain ID to convert
     * @return The corresponding LayerZero endpoint ID
     */
    function chainIdToEid(uint256 _chainId) external view returns (uint32);
}
