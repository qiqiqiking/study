// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Beg is Ownable {
    // 记录每个捐赠者的累计捐赠金额（单位：wei）
    mapping(address => uint256) public donations;

    // 捐赠事件：记录每次捐赠
    event Donation(address indexed donor, uint256 amount);

    // 时间窗口：允许捐赠的开始和结束时间（Unix 时间戳）
    uint256 public donationStartTime;
    uint256 public donationEndTime;

    // 构造函数：设置所有者、捐赠时间窗口
    constructor(uint256 _durationDays) Ownable(msg.sender) {
        donationStartTime = block.timestamp;
        donationEndTime = block.timestamp + (_durationDays * 1 days);
    }

    // 捐赠函数：用户向合约发送 ETH
    receive() external payable {
        donate();
    }

    fallback() external payable {
        donate();
    }

    function donate() public payable {
        require(msg.value > 0, "Donation must be greater than 0");
        require(block.timestamp >= donationStartTime, "Donation not started yet");
        require(block.timestamp <= donationEndTime, "Donation period ended");

        donations[msg.sender] += msg.value;


        emit Donation(msg.sender, msg.value);
    }

    // 查询某地址的捐赠总额
    function getDonation(address donor) public view returns (uint256) {
        return donations[donor];
    }

    // 所有者提取全部资金
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(balance);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}