// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MergeSortedArrays {
    function merge(
        uint256[] memory arr1,
        uint256[] memory arr2
    ) public pure returns (uint256[] memory) {
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;
        uint256 totalLen = len1 + len2;

        // 结果数组
        uint256[] memory merged = new uint256[](totalLen);

        uint256 i = 0; // arr1 ptr
        uint256 j = 0; // arr2 ptr
        uint256 k = 0; // merged ptr

        while (i < len1 && j < len2) {
            if (arr1[i] <= arr2[j]) {
                merged[k] = arr1[i];
                i++;
            } else {
                merged[k] = arr2[j];
                j++;
            }
            k++;
        }

        // 复制 arr1 剩的
        while (i < len1) {
            merged[k] = arr1[i];
            i++;
            k++;
        }

        // 复制 arr2 剩的
        while (j < len2) {
            merged[k] = arr2[j];
            j++;
            k++;
        }

        return merged;
    }


}