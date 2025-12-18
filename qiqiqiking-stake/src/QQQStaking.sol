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
        uint256 accQQQPerST;   //每单位质押累计奖励
        uint256 stTokenAmount;      // 质押的代币数量
        uint256 minDepositAmount;   //最小质押数量
        uint256 unstakeLockedBlocks;//解质押锁定的区块高度
    }
    struct UnstakeRequest {
        uint256 amount; // 用户取消质押的代币数量，要取出多少个 token
        uint256 unlockBlocks; // 解质押的区块高度
    }
    struct User {// 记录用户相对每个资金池 的质押记录
        uint256 stAmount;  // 用户在当前资金池，质押的代币数量
        uint256 finishedQQQ;// 用户在当前资金池，已经领取的 QQQ 数量
        uint256 pendingQQQ;// 用户在当前资金池，当前可领取的 QQQ 数量
        UnstakeRequest[] requests; // 用户在当前资金池，取消质押的记录
    }
    uint256 public startBlock; // 质押开始区块高度
    uint256 public endBlock; // 质押结束区块高度
    uint256 public QQQPerBlock; // 每个区块高度，QQQ 的奖励数量
    bool public withdrawPaused; // 是否暂停提现
    bool public claimPaused; // 是否暂停领取
    IERC20 public QQQ; // QQQ 代币地址
    uint256 public totalPoolWeight; // 所有资金池的权重总和
    Pool[] public pools; // 资金池列表
    mapping(uint256 => mapping(address => User)) public userInfoMap; // 资金池 id => 用户地址 => 用户信息
    // --------事件-------
    /// @notice 设置 QQQ 奖励代币地址时触发
    /// @param QQQ 新设置的 QQQ 代币合约地址
    event SetQQQ(IERC20 indexed QQQ);
    /// @notice 管理员暂停提现功能时触发
    event PauseWithdraw();
    /// @notice 管理员恢复提现功能时触发
    event UnpauseWithdraw();
    /// @notice 管理员暂停奖励领取功能时触发
    event PauseClaim();
    /// @notice 管理员恢复奖励领取功能时触发
    event UnpauseClaim();
    /// @notice 更新质押开始区块高度时触发
    /// @param startBlock 新的质押起始区块号
    event SetStartBlock(uint256 indexed startBlock);
    /// @notice 更新质押结束区块高度时触发
    /// @param endBlock 新的质押终止区块号
    event SetEndBlock(uint256 indexed endBlock);

    /// @notice 更新每区块发放的 QQQ 奖励数量时触发
    /// @param QQQPerBlock 每区块奖励的 QQQ 数量
    event SetQQQPerBlock(uint256 indexed QQQPerBlock);

    /// @notice 添加新的质押池时触发
    /// @param stTokenAddress 质押代币地址（ETH 用 address(0) 表示）
    /// @param poolWeight 该池子的权重（影响奖励分配比例）
    /// @param lastRewardBlock 该池子初始化时的最新奖励区块号
    /// @param minDepositAmount 最小质押数量（可为 0）
    /// @param unstakeLockedBlocks 解质押后的锁定区块数
    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );

    /// @notice 更新指定质押池的配置参数（最小质押额和解质押锁定期）时触发
    /// @param poolId 质押池 ID
    /// @param minDepositAmount 更新后的最小质押数量
    /// @param unstakeLockedBlocks 更新后的解质押锁定区块数
    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unstakeLockedBlocks
    );

    /// @notice 更新指定质押池的权重时触发
    /// @param poolId 质押池 ID
    /// @param poolWeight 更新后的池子权重
    /// @param totalPoolWeight 所有池子权重总和（更新后）
    event SetPoolWeight(
        uint256 indexed poolId,
        uint256 indexed poolWeight,
        uint256 totalPoolWeight
    );

    /// @notice 更新指定质押池的奖励状态（accQQQPerST 和 lastRewardBlock）时触发
    /// @param poolId 质押池 ID
    /// @param lastRewardBlock 更新后的最新奖励区块号
    /// @param totalQQQ 本次更新所分配的 QQQ 奖励总量（用于该池）
    event UpdatePool(
        uint256 indexed poolId,
        uint256 indexed lastRewardBlock,
        uint256 totalQQQ
    );

    /// @notice 用户向指定池子存入质押资产时触发
    /// @param user 存款用户地址
    /// @param poolId 质押池 ID
    /// @param amount 存入的质押代币数量（ETH 或 ERC20）
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    /// @notice 用户发起解质押请求（进入锁定期）时触发
    /// @param user 发起请求的用户地址
    /// @param poolId 质押池 ID
    /// @param amount 请求解质押的代币数量
    event RequestUnstake(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    /// @notice 用户成功提取已解锁的解质押资金时触发
    /// @param user 提现用户地址
    /// @param poolId 质押池 ID
    /// @param amount 实际提取的代币数量
    /// @param blockNumber 提现发生的区块高度（用于前端追踪）
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 indexed blockNumber
    );

    /// @notice 用户成功领取 QQQ 奖励时触发
    /// @param user 领取奖励的用户地址
    /// @param poolId 质押池 ID
    /// @param QQQReward 实际领取的 QQQ 奖励数量
    event Claim(
        address indexed user,
        uint256 indexed poolId,
        uint256 QQQReward
    );

    /// @dev 检查传入的质押池 ID 是否有效（防止数组越界）
    /// @param _pid 质押池索引，必须小于当前池子总数（pool.length）
    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }

    /// @dev 确保“领取奖励”功能未被管理员暂停
    ///      若 claimPaused == true，则禁止调用受保护的函数
    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    /// @dev 确保“提现（提取已解锁的解质押资金）”功能未被管理员暂停
    ///      若 withdrawPaused == true，则禁止调用受保护的函数
    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }


    /**
    * @notice 初始化合约的核心参数和权限系统。
    *         此函数用于在代理模式（Proxy Pattern）下完成一次性配置，
    *         相当于传统构造函数（constructor）在可升级合约中的替代方案。
    * @dev    仅可在合约部署后首次调用一次（由 `initializer` 修饰器保证）。
    *         调用者将被授予所有关键管理角色。
    * @param _QQQ          奖励代币（QQQ）的 ERC20 合约地址
    * @param _startBlock        质押奖励开始发放的区块高度（含）
    * @param _endBlock          质押奖励停止发放的区块高度（含）
     * @param _QQQPerBlock  每个区块向所有质押池分配的 QQQ 奖励总量
     */
    function initialize(
        IERC20 _QQQ,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _QQQPerBlock
    ) public initializer {
        // 校验输入参数的合法性：
        // - 起始区块不能晚于结束区块（防止时间倒流或无效区间）
        // - 每区块奖励必须大于 0（避免奖励为零导致用户无法获得收益）
        require(
            _startBlock <= _endBlock && _QQQPerBlock > 0,
            "invalid parameters"
        );

        // ========== 初始化 OpenZeppelin 继承模块 ==========
        // 初始化 UUPSUpgradeable 模块（支持通过逻辑合约自身升级）
        __UUPSUpgradeable_init();
        // 初始化 AccessControl 模块（用于基于角色的权限控制）
        __AccessControl_init();
        // 将调用者（通常是部署者）设为默认管理员（DEFAULT_ADMIN_ROLE）
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // 授予调用者 UPGRADE_ROLE：允许其调用 _authorizeUpgrade 进行合约升级
        _grantRole(UPGRADE_ROLE, msg.sender);
        // 授予调用者自定义 ADMIN_ROLE：可用于后续管理业务功能（如暂停/恢复）
        _grantRole(ADMIN_ROLE, msg.sender);
        // 设置 QQQ 奖励代币地址（内部会触发 SetQQQ 事件）
        setQQQ(_QQQ);

        // 记录质押活动的有效区块范围
        startBlock = _startBlock;   // 奖励从该区块开始计算
        endBlock = _endBlock;       // 到该区块后不再发放新奖励

        // 设置每区块总奖励量（所有质押池按权重瓜分此数量）
        QQQPerBlock = _QQQPerBlock;
    }

}
