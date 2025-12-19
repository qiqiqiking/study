// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QQQ.sol";
import "../src/QQQStaking.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        // 1. 获取部署者的私钥 (从 .env 文件读取)
        // 如果在本地 anvil 测试，可以直接用 vm.startBroadcast() 不带参数
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // ==========================================
        // 第一步：部署 QQQ 代币 (奖励代币)
        // ==========================================
        QQQ qqq = new QQQ();
        console.log("QQQ Token Deployed at:", address(qqq));

        // ==========================================
        // 第二步：部署 Staking 逻辑合约 (Implementation)
        // ==========================================
        QQQStaking implementation = new QQQStaking();
        console.log("Implementation Deployed at:", address(implementation));

        // ==========================================
        // 第三步：准备初始化参数并部署代理合约 (Proxy)
        // ==========================================

        // 设置初始化参数
        uint256 _rewardPerBlock = 10 ether; // 每个区块奖励 10 QQQ
        uint256 _startBlock = block.number + 100;
        uint256 _endBlock = block.number + 2000000; // 假设持续 200万个区块

        // 编码 initialize 函数调用数据
        bytes memory initData = abi.encodeWithSelector(
            QQQStaking.initialize.selector,
            address(qqq),    // 1. _QQQ
            _startBlock,     // 2. _startBlock
            _endBlock,       // 3. _endBlock
            _rewardPerBlock  // 4. _QQQPerBlock
        );

        // 部署代理合约，指向逻辑合约，并执行 initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // 将代理地址包装成 QQQStaking 接口，方便后续调用
        QQQStaking staking = QQQStaking(address(proxy));
        console.log("Staking Proxy (User interacts here) at:", address(staking));

        // ==========================================
        // 第四步：后续设置 (资金注入 & 权限)
        // ==========================================

        // 1. 转账 QQQ 到 Staking 合约用于发奖励
        // 注意：因为是你部署的 QQQ，初始供应量通常在部署者手里
        uint256 fundingAmount = 1000000 ether;
        qqq.transfer(address(staking), fundingAmount);
        console.log("Transferred", fundingAmount, "QQQ to Staking Contract");

        // 2. 添加 ETH 池 (Pool ID 0)
        // 注意：根据你的代码逻辑，必须有 Pool 0 才能运作
        staking.addPool(address(0), 100, 1, 10, true);
        console.log("Added ETH Pool (PID 0)");

        vm.stopBroadcast();
    }
}