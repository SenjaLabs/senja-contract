// Copyright (C) 2022 The Klaytn Authors
// Copyright (C) 2015, 2016, 2017 Dapphub

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.5.9;

/**
 * @title WKAIA
 * @notice Wrapped KAIA token that allows native KAIA to be used as an ERC20 token
 * @dev Implementation of a wrapped native token allowing deposits and withdrawals
 */
contract WKAIA {
    /// @notice The name of the token
    string public name = "Wrapped Klay";
    /// @notice The symbol of the token
    string public symbol = "WKLAY";
    /// @notice The number of decimal places for the token
    uint8 public decimals = 18;

    /// @notice Emitted when an approval is granted
    /// @param src The address granting the approval
    /// @param guy The address receiving the approval
    /// @param wad The amount approved
    event Approval(address indexed src, address indexed guy, uint256 wad);

    /// @notice Emitted when tokens are transferred
    /// @param src The address sending the tokens
    /// @param dst The address receiving the tokens
    /// @param wad The amount transferred
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    /// @notice Emitted when native KAIA is deposited and wrapped
    /// @param dst The address receiving the wrapped tokens
    /// @param wad The amount deposited
    event Deposit(address indexed dst, uint256 wad);

    /// @notice Emitted when wrapped tokens are unwrapped to native KAIA
    /// @param src The address withdrawing the tokens
    /// @param wad The amount withdrawn
    event Withdrawal(address indexed src, uint256 wad);

    /// @notice Mapping of addresses to their token balances
    mapping(address => uint256) public balanceOf;

    /// @notice Mapping of token allowances from owner to spender
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * @notice Receive function to wrap native KAIA sent to the contract
     * @dev Automatically calls deposit() when native KAIA is received
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Fallback function to wrap native KAIA sent to the contract
     * @dev Automatically calls deposit() when native KAIA is received via fallback
     */
    fallback() external payable {
        deposit();
    }

    /**
     * @notice Deposits native KAIA and mints equivalent wrapped tokens
     * @dev Increases the caller's wrapped token balance by the amount of KAIA sent
     */
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws wrapped tokens and returns equivalent native KAIA
     * @dev Burns wrapped tokens and transfers native KAIA back to the caller
     * @param wad The amount of wrapped tokens to unwrap
     */
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    /**
     * @notice Returns the total supply of wrapped tokens
     * @dev Total supply equals the contract's native KAIA balance
     * @return The total supply of wrapped tokens
     */
    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Approves an address to spend tokens on behalf of the caller
     * @param guy The address being approved to spend tokens
     * @param wad The amount of tokens approved for spending
     * @return True if the approval was successful
     */
    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    /**
     * @notice Transfers tokens from the caller to a destination address
     * @param dst The address to receive the tokens
     * @param wad The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    /**
     * @notice Transfers tokens from one address to another using allowance mechanism
     * @dev If caller is not the source, requires sufficient allowance
     * @param src The address to transfer tokens from
     * @param dst The address to transfer tokens to
     * @param wad The amount of tokens to transfer
     * @return True if the transfer was successful
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
