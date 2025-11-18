// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MOCKWBTC is ERC20 {
    constructor() ERC20("Wrapped Bitcoin", "WBTC") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }
}

