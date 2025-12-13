// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Counter {
    uint256 public count = 0;

    function increment() external {
        count += 1;
    }

    function getCount() external view returns (uint256) {
        return count;
    }
}