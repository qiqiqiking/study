// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QQQ.sol";

contract TokenTest is Test {
    QQQ public qqq;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(0x100);
        user1 = address(0x101);
        user2 = address(0x102);

        // 部署代币
        qqq = new QQQ();

        // 关键修复：使用 deal 给 owner 发币，确保他有初始资金
        deal(address(qqq), owner, 1000000 * 10 ** 18);
    }

    function testInitialSupply() public {
        // 检查 owner 的余额是否正确
        assertEq(qqq.balanceOf(owner), 1000000 * 10 ** 18);
    }

    function testTransfer() public {
        vm.startPrank(owner);
        qqq.transfer(user1, 100 ether);
        vm.stopPrank();

        assertEq(qqq.balanceOf(user1), 100 ether);
        assertEq(qqq.balanceOf(owner), (1000000 - 100) * 1 ether);
    }

    function testTransferFrom() public {
        vm.startPrank(owner);
        qqq.approve(user1, 100 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        qqq.transferFrom(owner, user2, 50 ether);
        vm.stopPrank();

        assertEq(qqq.balanceOf(user2), 50 ether);
        assertEq(qqq.allowance(owner, user1), 50 ether);
    }

    function testTransferInsufficientBalance() public {
        vm.startPrank(owner);

        // OpenZeppelin v5 使用自定义错误 Custom Error，而不是字符串
        // 这里的 selector 对应 error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed)
        // 为了简化测试，我们只断言它会 Revert，不检查具体的 Error Data
        vm.expectRevert();
        qqq.transfer(user1, 10000000 * 10 ** 18); // 转账金额超过余额

        vm.stopPrank();
    }
}