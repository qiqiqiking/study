// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract StringReverser {

    function reverseString(string memory _str) public pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        uint256 length = strBytes.length;
        if (length <= 1) {
            return _str;
        }

        // 创建结果字节数组
        bytes memory reversed = new bytes(length);

        // 从后往前复制字符
        for (uint256 i = 0; i < length; i++) {
            reversed[i] = strBytes[length - 1 - i];
        }

        return string(reversed);
    }


}