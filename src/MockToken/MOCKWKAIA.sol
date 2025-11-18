// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title MOCKWKAIA
 * @dev Mock Wrapped Native token for testing purposes
 * @notice This contract extends the standard WKAIA functionality with mint/burn for testing
 */
contract MOCKWKAIA {
    string public name = "Wrapped Klay";
    string public symbol = "WKLAY";
    uint8 public decimals = 18;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event Mint(address indexed to, uint256 wad);
    event Burn(address indexed from, uint256 wad);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private _totalSupply;

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        _totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "Insufficient balance");
        balanceOf[msg.sender] -= wad;
        _totalSupply -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Mint tokens for testing purposes
     * @param to Address to mint tokens to
     * @param wad Amount to mint
     */
    function mint(address to, uint256 wad) public {
        require(to != address(0), "Mint to zero address");
        balanceOf[to] += wad;
        _totalSupply += wad;
        emit Mint(to, wad);
        emit Transfer(address(0), to, wad);
    }

    /**
     * @notice Burn tokens from an address for testing purposes
     * @param from Address to burn tokens from
     * @param wad Amount to burn
     */
    function burn(address from, uint256 wad) public {
        require(balanceOf[from] >= wad, "Insufficient balance to burn");
        balanceOf[from] -= wad;
        _totalSupply -= wad;
        emit Burn(from, wad);
        emit Transfer(from, address(0), wad);
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

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
