// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract BinarySearch {

    function search(
        uint256[] memory arr,
        uint256 target
    ) public pure returns (bool found, uint256 index) {
        return _binarySearch(arr, target);
    }


    function _binarySearch(
        uint256[] memory arr,
        uint256 target
    ) private pure returns (bool, uint256) {
        uint256 left = 0;
        uint256 right = arr.length;

        if (right == 0) {
            return (false, 0);
        }

        while (left < right) {
            uint256 mid = left + (right - left) / 2;

            if (arr[mid] == target) {
                return (true, mid);
            } else if (arr[mid] < target) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return (false, 0);
    }


}