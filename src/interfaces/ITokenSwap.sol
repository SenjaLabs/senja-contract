// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
██╗██████╗░██████╗░░█████╗░███╗░░██╗
██║██╔══██╗██╔══██╗██╔══██╗████╗░██║
██║██████╦╝██████╔╝███████║██╔██╗██║
██║██╔══██╗██╔══██╗██╔══██║██║╚████║
██║██████╦╝██║░░██║██║░░██║██║░╚███║
╚═╝╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝
*/

/**
 * @title ITokenSwap
 * @dev Interface for token swap and bridge functionality
 * @notice This interface defines the contract for token minting, burning, and cross-chain bridging
 * @author Ibran Team
 * @custom:security-contact security@ibran.com
 * @custom:version 1.0.0
 */
interface ITokenSwap {
    /**
     * @dev Mints new tokens to a specified address
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     * @notice This function creates new tokens and assigns them to the recipient
     * @custom:security Only authorized addresses should be able to mint tokens
     */
    function mint(address _to, uint256 _amount) external;
    
    /**
     * @dev Burns tokens from the caller's balance
     * @param _amount Amount of tokens to burn
     * @notice This function destroys tokens from the caller's balance
     * @custom:security Users can only burn their own tokens
     */
    function burn(uint256 _amount) external;
    
    /**
     * @dev Grants mint and burn roles to a specified address
     * @param _to Address to grant the roles to
     * @notice This function authorizes an address to mint and burn tokens
     * @custom:security Only the contract owner should be able to grant roles
     */
    function grantMintAndBurnRoles(address _to) external;
    
    /**
     * @dev Mints mock tokens for testing purposes
     * @param _to Address to receive the minted mock tokens
     * @param _amount Amount of mock tokens to mint
     * @notice This function is used for testing and development
     * @custom:security This function should only be available in test environments
     */
    function mintMock(address _to, uint256 _amount) external;
    
    /**
     * @dev Burns mock tokens for testing purposes
     * @param _amount Amount of mock tokens to burn
     * @notice This function is used for testing and development
     * @custom:security This function should only be available in test environments
     */
    function burnMock(uint256 _amount) external;
    
    /**
     * @dev Returns the bridge token sender for a specific chain and index
     * @param _chainId Chain ID for the bridge
     * @param _index Index of the bridge token sender
     * @return Address of the bridge token sender
     */
    function bridgeTokenSenders(uint256 _chainId, uint256 _index) external view returns (address);
    
    /**
     * @dev Adds a new bridge token sender
     * @param _bridgeTokenSender Address of the bridge token sender to add
     * @notice This function registers a new bridge token sender for cross-chain operations
     * @custom:security Only authorized addresses should be able to add bridge token senders
     */
    function addBridgeTokenSender(address _bridgeTokenSender) external;
    
    /**
     * @dev Returns the number of bridge token senders for a specific chain
     * @param _chainId Chain ID to query
     * @return Number of bridge token senders for the chain
     */
    function getBridgeTokenSendersLength(uint256 _chainId) external view returns (uint256);
}
