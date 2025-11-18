// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract STOKEN is ERC20, Ownable {
    mapping(address => bool) public operator;

    uint8 private immutable _DECIMALS;

    error NotOperator();

    constructor(string memory _name, string memory _symbol, uint8 __decimals)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        _DECIMALS = __decimals;
    }

    modifier onlyOperator() {
        _onlyOperator();
        _;
    }

    function _onlyOperator() internal view {
        if (!operator[msg.sender]) revert NotOperator();
    }

    function decimals() public view override returns (uint8) {
        return _DECIMALS;
    }

    function setOperator(address _operator, bool _isOperator) public onlyOwner {
        operator[_operator] = _isOperator;
    }

    function mint(address _to, uint256 _amount) public onlyOperator {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyOperator {
        _burn(_from, _amount);
    }
}
