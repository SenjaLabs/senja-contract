// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMintableBurnable} from "../interfaces/IMintableBurnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ElevatedMinterBurner is Ownable {
    event Burn(address indexed from, address indexed to, uint256 amount);
    event Mint(address indexed to, address indexed from, uint256 amount);

    address public immutable TOKEN;
    mapping(address => bool) public operators;

    using SafeERC20 for IERC20;

    modifier onlyOperators() {
        _onlyOperators();
        _;
    }

    function _onlyOperators() internal view {
        require(operators[msg.sender] || msg.sender == owner(), "Not authorized");
    }

    constructor(address _token, address _owner) Ownable(_owner) {
        TOKEN = _token;
    }

    function setOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
    }

    function burn(address _from, uint256 _amount) external onlyOperators returns (bool) {
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
        IMintableBurnable(TOKEN).burn(address(this), _amount);
        emit Burn(_from, msg.sender, _amount);
        return true;
    }

    function mint(address _to, uint256 _amount) external onlyOperators returns (bool) {
        IMintableBurnable(TOKEN).mint(_to, _amount);
        emit Mint(_to, msg.sender, _amount);
        return true;
    }
}
