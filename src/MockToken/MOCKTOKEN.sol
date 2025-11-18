// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MOCKTOKEN is ERC20 {
    uint8 private immutable _DECIMALS;

    constructor(string memory _name, string memory _symbol, uint8 __decimals) ERC20(_name, _symbol) {
        _DECIMALS = __decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _DECIMALS;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }
}

