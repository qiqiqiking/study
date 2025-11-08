// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract RomanToInteger {

    function romanToInt(string memory roman) public pure returns (uint256) {
        bytes memory r = bytes(roman);
        uint256 length = r.length;

        require(length > 0, "Roman string cannot be empty");

        uint256 total = 0;
        uint256 prevValue = 0;
        for (uint256 i = length; i > 0; ) {
            i--;
            uint256 currentValue = getValue(r[i]);

            if (currentValue < prevValue) {
                total -= currentValue;
            } else {
                total += currentValue;
            }

            prevValue = currentValue;
        }

        return total;
    }


    function getValue(byte c) private pure returns (uint256) {
        if (c == 'I') return 1;
        if (c == 'V') return 5;
        if (c == 'X') return 10;
        if (c == 'L') return 50;
        if (c == 'C') return 100;
        if (c == 'D') return 500;
        if (c == 'M') return 1000;
        revert("Invalid Roman numeral character");
    }
}