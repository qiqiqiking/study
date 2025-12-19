// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QQQ.sol";
import "../src/QQQStaking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLP is ERC20 {
    constructor() ERC20("Mock LP", "MLP") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract StakingTest is Test {
    QQQ public qqq;
    MockLP public lpToken;
    QQQStaking public staking;

    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(0x100);
        user1 = address(0x101);
        user2 = address(0x102);

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.roll(100);

        qqq = new QQQ();
        lpToken = new MockLP();
        staking = new QQQStaking();

        vm.startPrank(owner);
        staking.initialize(qqq, 100, 200, 10 * 10**18);
        vm.stopPrank();

        deal(address(qqq), address(staking), 100000 * 10**18);
    }

    // --- Happy Paths ---

    function testInitialize() public {
        assertEq(address(staking.QQQ()), address(qqq));
        assertEq(staking.startBlock(), 100);
        assertEq(staking.endBlock(), 200);
        assertEq(staking.QQQPerBlock(), 10 * 10**18);
    }

    function testAddPool() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        staking.addPool(address(lpToken), 200, 1, 15, true);
        vm.stopPrank();

        assertEq(staking.poolLength(), 2);
    }

    function testDepositETH() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();
        vm.stopPrank();

        (,,,, uint256 stAmount,,) = staking.pools(0);
        assertEq(stAmount, 10 ether);
    }

    function testDepositERC20() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        staking.addPool(address(lpToken), 100, 1, 15, true);
        vm.stopPrank();

        lpToken.mint(user1, 100 ether);

        vm.startPrank(user1);
        lpToken.approve(address(staking), 100 ether);
        staking.deposit(1, 10 ether);
        vm.stopPrank();

        (,,,, uint256 stAmount,,) = staking.pools(1);
        assertEq(stAmount, 10 ether);
    }

    function testUnstakeAndWithdraw() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();
        vm.stopPrank();

        vm.roll(110);

        vm.startPrank(user1);
        staking.unstake(0, 5 ether);
        vm.stopPrank();

        vm.roll(121);

        (uint256 reqAmount, uint256 pendingWithdraw) = staking.withdrawAmount(0, user1);
        assertEq(reqAmount, 5 ether);
        assertEq(pendingWithdraw, 5 ether);

        vm.startPrank(user1);
        staking.withdraw(0);
        vm.stopPrank();

        assertEq(staking.stakingBalance(0, user1), 5 ether);
    }

    function testClaimReward() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();
        vm.stopPrank();

        vm.roll(110);

        vm.startPrank(user1);
        staking.claim(0);
        vm.stopPrank();

        assertGt(qqq.balanceOf(user1), 0);
    }

    function testPauseAndResume() public {
        vm.startPrank(owner);
        staking.pauseWithdraw();
        vm.stopPrank();
        assertEq(staking.withdrawPaused(), true);

        vm.startPrank(owner);
        staking.unpauseWithdraw();
        vm.stopPrank();
        assertEq(staking.withdrawPaused(), false);

        vm.startPrank(owner);
        staking.pauseClaim();
        vm.stopPrank();
        assertEq(staking.claimPaused(), true);
    }

    // --- Unhappy Paths & Edge Cases ---

    function testCannotDepositZero() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        staking.depositETH{value: 0}();
        vm.stopPrank();
    }

    function testCannotWithdrawLocked() public {
        vm.startPrank(owner);
        // 设置锁定期为 20 个区块
        staking.addPool(address(0), 100, 1, 20, true);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();

        // 申请解质押 5 ETH
        staking.unstake(0, 5 ether);
        vm.stopPrank();

        // 只过了 5 个区块 (当前 block + 5)，此时应该还在锁定期 (需 20 个块)
        vm.roll(block.number + 5);

        // 记录提现前的余额
        uint256 balanceBefore = address(user1).balance;

        vm.startPrank(user1);

        // 因为合约并没有 Revert，而是提取了 0
        staking.withdraw(0);

        vm.stopPrank();

        uint256 balanceAfter = address(user1).balance;
        assertEq(balanceAfter, balanceBefore, "Should not receive ETH while locked");

        // 可选：验证该笔待提现资金依然存在
        (uint256 reqAmount, uint256 pendingWithdraw) = staking.withdrawAmount(0, user1);
        // reqAmount 应该还是 5 ETH，因为它还没被成功提取
        assertEq(reqAmount, 5 ether);
        // pendingWithdraw 应该是 0，因为还在锁定期，暂不可取
        assertEq(pendingWithdraw, 0);
    }

    function testOnlyAdminCanAddPool() public {
        vm.startPrank(user2);
        vm.expectRevert();
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();
    }


    function testSetPool() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);

        // 使用 setPoolWeight 修改权重
        staking.setPoolWeight(0, 500, true);
        vm.stopPrank();

        (,uint256 weight,,,,,) = staking.pools(0);
        assertEq(weight, 500);
    }

    function testPendingQQQ() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();
        vm.stopPrank();

        vm.roll(110);

        uint256 pending = staking.pendingQQQ(0, user1);
        assertEq(pending, 100 * 10**18);
    }



    // 1. 测试：暂停状态下禁止操作 (覆盖 Pausable 相关的 else 分支)
    function testCannotActionWhenPaused() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        staking.pauseClaim();
        staking.pauseWithdraw(); // 初始暂停
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();
        vm.roll(110);

        // 1. 测试 Claim 报错 (正确)
        vm.expectRevert(); // 期望报错 "claim is paused" 或类似
        staking.claim(0);
        vm.stopPrank(); // 结束 user1

        // --- 中场操作：为了测试 withdraw，必须先 unstake ---

        // 2. 切换回 Owner，临时恢复 Withdraw 权限，以便我们能 unstake
        vm.startPrank(owner);
        staking.unpauseWithdraw();
        vm.stopPrank();

        // 3. 切换回 User1，执行 unstake
        vm.startPrank(user1);
        staking.unstake(0, 5 ether);
        vm.stopPrank();

        // 4. 切换回 Owner，再次暂停 Withdraw (为了测试下一步 withdraw 会失败)
        vm.startPrank(owner);
        staking.pauseWithdraw();
        vm.stopPrank();

        // --- 最终测试 ---

        vm.startPrank(user1);
        vm.roll(150); // 确保过了锁定期

        // 5. 测试：虽然过了锁定期，但因为暂停了，所以 Withdraw 应该报错
        vm.expectRevert(); // 期望报错 "withdraw is paused"
        staking.withdraw(0);
        vm.stopPrank();
    }
    // 2. 测试：解质押金额超过余额 (覆盖 sub 运算溢出/检查分支)
    function testCannotUnstakeMoreThanBalance() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();

        // 只有 10 ETH，尝试取 20 ETH
        vm.expectRevert();
        staking.unstake(0, 20 ether);
        vm.stopPrank();
    }

    // 3. 测试：不存在的 Pool ID (覆盖 pools 数组越界分支)
    function testInvalidPoolID() public {
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // 尝试向不存在的 PID (99) 存款
        vm.expectRevert();
        staking.depositETH{value: 10 ether}();
        // 注意：如果是 depositETH，通常不需要 PID 参数，如果是 deposit(pid, amount) 则需要
        // 这里假设 depositETH 内部写死 pid=0，如果 depositETH 不需要 pid，则测试 deposit

        // 测试 ERC20 deposit 到错误 PID
        vm.expectRevert();
        staking.deposit(99, 10 ether);
        vm.stopPrank();
    }

    // 4. 测试：重复初始化 (覆盖 Initializable 的分支)
    function testCannotInitializeTwice() public {
        vm.startPrank(owner);
        vm.expectRevert(); // Initializable: contract is already initialized
        staking.initialize(qqq, 100, 200, 10);
        vm.stopPrank();
    }

    // 5. 测试：所有 Admin 函数的权限控制 (不仅是 addPool)
    function testAdminFunctionsRestricted() public {
        vm.startPrank(user2); // 非 Admin 用户

        // 测试 setPoolWeight
        vm.expectRevert();
        staking.setPoolWeight(0, 100, true);

        // 测试 updatePool (如果有这个 public 函数)
        // vm.expectRevert();
        // staking.updatePool(0);

        // 测试 pause/unpause
        vm.expectRevert();
        staking.pauseClaim();

        vm.expectRevert();
        staking.unpauseClaim();

        vm.stopPrank();
    }

    // 6. 测试：UpdatePool 的边界条件 (block.number <= lastRewardBlock)
    function testUpdatePoolEarly() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        // 当前 block 是 100，lastRewardBlock 也是 100
        // 此时调用 updatePool 应该直接 return (覆盖那个 if return 分支)
        vm.roll(100);
        staking.updatePool(0); // 这次调用不会产生奖励，也不会报错，但会覆盖代码分支
    }


    function testRewardTokenInsufficient() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        // 这里的关键：把合约里的 QQQ 掏空，只留一点点
        // 假设用户应得 100 QQQ，但合约里只有 50 QQQ
        uint256 contractBal = 50 * 10**18;
        // 先清空，再给 50
        deal(address(qqq), address(staking), contractBal);

        vm.startPrank(user1);
        staking.depositETH{value: 10 ether}();
        vm.roll(110); // 产生 100 QQQ 的奖励 (10 blocks * 10 per block)

        // 此时用户应得 100，但合约只有 50
        // 这将触发 if (_amount > QQQBal) 分支
        staking.claim(0);
        vm.stopPrank();

        // 验证用户只收到了合约仅有的 50 QQQ
        assertEq(qqq.balanceOf(user1), contractBal);
        // 验证合约被掏空
        assertEq(qqq.balanceOf(address(staking)), 0);
    }
}


// ⛔️ 恶意合约：拒绝接收 ETH
contract RejectETH {
    // receive 必须存在，否则 transfer 可能会因为找不到 fallback 而报错（取决于具体实现）
    // 这里我们显式让它 revert
    receive() external payable {
        revert("I hate ETH");
    }

    // 辅助函数：帮我们去质押
    function doDeposit(address _staking) external payable {
        QQQStaking(_staking).depositETH{value: msg.value}();
    }

    // 辅助函数：帮我们去提现
    function doWithdraw(address _staking, uint256 _pid) external {
        QQQStaking(_staking).withdraw(_pid);
    }
}

// 重新打开 StakingTest 继续写测试
contract StakingTestPart2 is StakingTest {
    // 注意：为了方便，你可以直接把下面这个测试函数放回上面的 StakingTest 里
    // 记得把 RejectETH 定义在 StakingTest 之外

    // 2. 测试：ETH 转账失败 (覆盖 _safeETHTransfer 的 !success 分支)
    function testSafeETHTransferFailed() public {
        RejectETH badActor = new RejectETH();
        vm.deal(address(badActor), 100 ether);

        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 1, true);
        vm.stopPrank();

        // 恶意合约去存款
        vm.startPrank(address(badActor));
        QQQStaking(address(staking)).depositETH{value: 10 ether}();

        QQQStaking(address(staking)).unstake(0, 10 ether);
        vm.stopPrank();

        vm.roll(block.number + 2);

        vm.startPrank(address(badActor));
        // 期望报错：因为 RejectETH 的 receive() 会 revert，导致 safeTransferETH 失败
        vm.expectRevert();
        QQQStaking(address(staking)).withdraw(0);
        vm.stopPrank();
    }
    // 3. 测试：零权重池子 (覆盖 updatePool 中的 if (pool.poolWeight == 0) 分支)
    function testZeroWeightPool() public {
        vm.startPrank(owner);

        // 1. 添加 PID 0 (ETH池): 必须是第一个添加的。
        //    我们将它的权重设为 0 <--- 这就是我们要测试的目标
        staking.addPool(address(0), 0, 1, 10, true);

        // 2. 添加 PID 1 (辅助池): 必须添加第二个池子并给它权重
        //    这是为了确保 totalPoolWeight > 0，防止合约计算奖励时除以零报错
        staking.addPool(address(lpToken), 100, 1, 10, true);

        vm.stopPrank();

        vm.startPrank(user1);
        // 3. 向 PID 0 (ETH, 权重0) 存款
        staking.depositETH{value: 10 ether}();

        // 4. 前进产生奖励 (理论上产生了 100 QQQ)
        vm.roll(110);

        // 5. 领取 PID 0 的奖励
        staking.claim(0);
        vm.stopPrank();

        // 6. 断言: 尽管过了很多区块，但因为 Pool 0 的权重是 0，
        //    所有的奖励都应该分给 Pool 1 (尽管 Pool 1 没人玩)，
        //    所以 User 1 获得的奖励应该严格为 0。
        assertEq(qqq.balanceOf(user1), 0);
    }
}


contract StakingTestPart3 is StakingTest {

    // 1. 测试：无人质押时的更新逻辑
    function testUpdatePoolWithZeroStaked() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);

        // 然后添加我们要测试的 PID 1 (ERC20池)
        staking.addPool(address(lpToken), 100, 1, 10, true);
        vm.stopPrank();

        // 获取 PID 1 的初始 accQQQPerST
        (,,, uint256 acc1,,,) = staking.pools(1);

        // 前进 100 个区块
        vm.roll(block.number + 100);

        // 更新 PID 1 (此时无人质押)
        staking.updatePool(1);

        // 再次获取
        (,,, uint256 acc2,,,) = staking.pools(1);

        // 验证：无人质押时，每股累积奖励不应增加
        assertEq(acc1, acc2, "AccQQQPerShare should not increase when no tokens staked");
    }

    // 2. 测试：尝试把 ERC20 存入 ETH 池
    function testCannotDepositERC20ToETHPool() public {
        vm.startPrank(user1);
        // 尝试对 PID 0 (ETH池) 调用普通 deposit，应该报错
        vm.expectRevert();
        staking.deposit(0, 10 ether);
        vm.stopPrank();
    }

    // 3. 测试：SetPoolWeight 不更新
    function testSetPoolWeightWithoutUpdate() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);

        // _withUpdate = false
        staking.setPoolWeight(0, 200, false);
        vm.stopPrank();

        (, uint256 weight,,,,,) = staking.pools(0);
        assertEq(weight, 200);
    }

    // 4. 测试：非 staker 查询 Pending
    function testPendingQQQForNonStaker() public {
        vm.startPrank(owner);
        staking.addPool(address(0), 100, 1, 10, true);
        vm.stopPrank();

        vm.roll(block.number + 100);

        uint256 pending = staking.pendingQQQ(0, user2);
        assertEq(pending, 0);
    }

    // 5. 测试：UUPS 升级权限
    function testUpgradeUnauthorized() public {
        QQQStaking newImpl = new QQQStaking();
        vm.startPrank(user2);
        vm.expectRevert();
        staking.upgradeToAndCall(address(newImpl), "");
        vm.stopPrank();
    }

    // 6. 测试：Initialize 参数校验
    function testInitializeValidation() public {
        QQQStaking newStaking = new QQQStaking();


    }
}