// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title QQQKING Token
/// @author qiqiqi
contract QQQ is ERC20, Ownable {
    uint8 private constant _DECIMALS = 18;
    uint256 private constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** _DECIMALS; // 1 billion tokens

    constructor() ERC20("QQQ", "QQQ") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function decimals() public view override returns (uint8) {
        return _DECIMALS;
    }
}