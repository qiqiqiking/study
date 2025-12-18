// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract QQQStaking is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20; //安全操作 ERC20 代币（防兼容性问题）
    //IERC20(pool_.stTokenAddress).safeTransferFrom(
    //    msg.sender,
    //    address(this),
    //    _amount
    //);
    using Math for uint256;  //安全/便捷的数学运算（max, min, ceilDiv 等）

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role"); //业务管理员角色 被 onlyRole(ADMIN_ROLE) 修饰符保护的函数，只有被授予此角色的地址才能调用。
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");//控制合约升级权限
    uint256 public constant ETH_PID = 0; //ETH 质押池的索引为 0


    struct Pool {                   //每种代币一个池子
        address stTokenAddress;     // 质押代币的地址
        uint256 poolWeight;         // 资金池所占权重
        uint256 lastRewardBlock;    // 上次奖励计算区块
        uint256 accMetaNodePerST;   //每单位质押累计奖励
        uint256 stTokenAmount;      // 质押的代币数量
        uint256 minDepositAmount;   //最小质押数量
        uint256 unstakeLockedBlocks;//解质押锁定的区块高度
    }


    struct UnstakeRequest {
        uint256 amount; // 用户取消质押的代币数量，要取出多少个 token
        uint256 unlockBlocks; // 解质押的区块高度
    }
}
