// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Voting {
    // 存储候选人的得票数
    mapping(string => uint256) public votes;

    // 投票函数
    function vote(string memory candidate) public {
        votes[candidate]++;
    }

    // 获取某个候选人的得票数
    function getVotes(string memory candidate) public view returns (uint256) {
        return votes[candidate];
    }

    // 重置所有候选人的得票数
    function resetVotes(string[] memory candidates) public {
        for (uint256 i = 0; i < candidates.length; i++) {
            votes[candidates[i]] = 0;
        }
    }
}