// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WETHk is ERC20, Ownable {
    mapping(address => bool) public operator;

    error NotOperator();

    constructor() ERC20("Wrapped ETH representative", "WETHk") Ownable(msg.sender) {}

    modifier onlyOperator() {
        _onlyOperator();
        _;
    }

    function _onlyOperator() internal view {
        if (!operator[msg.sender]) revert NotOperator();
    }

    function decimals() public pure override returns (uint8) {
        return 18;
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
