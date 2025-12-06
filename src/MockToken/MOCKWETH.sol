// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title MOCKWETH
 * @notice Mock Wrapped Ethereum token for testing purposes
 * @dev Implements WETH functionality with additional mint/burn capabilities for testing
 */
contract MOCKWETH {
    /// @notice Token name
    string public name = "Wrapped Ethereum";

    /// @notice Token symbol
    string public symbol = "WETH";

    /// @notice Token decimals (18 for Ethereum)
    uint8 public decimals = 18;

    /// @notice Emitted when approval is granted
    /// @param src Address granting approval
    /// @param guy Address receiving approval
    /// @param wad Amount approved
    event Approval(address indexed src, address indexed guy, uint256 wad);

    /// @notice Emitted when tokens are transferred
    /// @param src Source address
    /// @param dst Destination address
    /// @param wad Amount transferred
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    /// @notice Emitted when native ETH is deposited and wrapped
    /// @param dst Address receiving wrapped tokens
    /// @param wad Amount deposited
    event Deposit(address indexed dst, uint256 wad);

    /// @notice Emitted when wrapped tokens are withdrawn to native ETH
    /// @param src Address withdrawing tokens
    /// @param wad Amount withdrawn
    event Withdrawal(address indexed src, uint256 wad);

    /// @notice Emitted when tokens are minted for testing
    /// @param to Address receiving minted tokens
    /// @param wad Amount minted
    event Mint(address indexed to, uint256 wad);

    /// @notice Emitted when tokens are burned for testing
    /// @param from Address tokens are burned from
    /// @param wad Amount burned
    event Burn(address indexed from, uint256 wad);

    /// @notice Balances of token holders
    mapping(address => uint256) public balanceOf;

    /// @notice Allowances for token spending
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev Total token supply
    uint256 private _totalSupply;

    /**
     * @notice Receive function to accept ETH and wrap it
     * @dev Automatically calls deposit() when ETH is sent
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Fallback function to accept ETH and wrap it
     * @dev Automatically calls deposit() when ETH is sent with data
     */
    fallback() external payable {
        deposit();
    }

    /**
     * @notice Deposits native ETH and mints equivalent wrapped tokens
     * @dev Increases sender's balance and total supply by msg.value
     */
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        _totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws wrapped tokens and receives native ETH
     * @param wad Amount of wrapped tokens to withdraw
     * @dev Burns wrapped tokens and transfers equivalent ETH to sender
     */
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "Insufficient balance");
        balanceOf[msg.sender] -= wad;
        _totalSupply -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    /**
     * @notice Returns the total supply of wrapped tokens
     * @return Total supply amount
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Mints tokens for testing purposes
     * @param to Address to mint tokens to
     * @param wad Amount to mint
     * @dev Only for testing - increases supply without ETH backing
     */
    function mint(address to, uint256 wad) public {
        require(to != address(0), "Mint to zero address");
        balanceOf[to] += wad;
        _totalSupply += wad;
        emit Mint(to, wad);
        emit Transfer(address(0), to, wad);
    }

    /**
     * @notice Burns tokens from an address for testing purposes
     * @param from Address to burn tokens from
     * @param wad Amount to burn
     * @dev Only for testing - decreases supply without ETH withdrawal
     */
    function burn(address from, uint256 wad) public {
        require(balanceOf[from] >= wad, "Insufficient balance to burn");
        balanceOf[from] -= wad;
        _totalSupply -= wad;
        emit Burn(from, wad);
        emit Transfer(from, address(0), wad);
    }

    /**
     * @notice Approves an address to spend tokens on behalf of the caller
     * @param guy Address to approve
     * @param wad Amount to approve
     * @return Boolean indicating success
     */
    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    /**
     * @notice Transfers tokens to a destination address
     * @param dst Destination address
     * @param wad Amount to transfer
     * @return Boolean indicating success
     */
    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    /**
     * @notice Transfers tokens from one address to another
     * @param src Source address
     * @param dst Destination address
     * @param wad Amount to transfer
     * @return Boolean indicating success
     * @dev Checks allowance if caller is not the source address
     */
    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}
