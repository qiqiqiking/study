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
    /// @param _pid 质押池索引，必须小于当前池子总数（pools.length）
    modifier checkPid(uint256 _pid) {
        require(_pid < pools.length, "invalid pid");
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
        //__UUPSUpgradeable_init();
        //OpenZeppelin v4: UUPSUpgradeable 有一些状态需要初始化，所以必须调用 __UUPSUpgradeable_init()。
        //OpenZeppelin v5: 为了优化 Gas 和简化逻辑，UUPS 实现变成了**无状态（Stateless）**的。既然没有状态变量需要赋值，初始化函数自然就不存在了。

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


    /**
     * @dev UUPS 升级授权钩子函数。
    *      当通过代理合约调用 `upgradeTo` 或 `upgradeToAndCall` 时，
    *      代理会通过 delegatecall 触发此函数，用于验证升级请求是否被授权。
    *      调用者必须持有 `UPGRADE_ROLE` 角色才能执行升级，
    *      确保只有受信任的地址可以升级合约逻辑。
    *
    *      注意：此函数仅用于权限校验，不应包含任何状态修改或业务逻辑，
    *            以避免在升级过程中引入意外副作用。
    *
    * @param newImplementation 即将升级到的新逻辑合约地址
    */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADE_ROLE) {}
    
    //设置奖励代币
    function setQQQ(IERC20 _QQQ) public onlyRole(ADMIN_ROLE) {
        QQQ = _QQQ;

        emit SetQQQ(QQQ);
    }

    //暂停 恢复 提现
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");

        withdrawPaused = true;

        emit PauseWithdraw();
    }
    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");

        withdrawPaused = false;

        emit UnpauseWithdraw();
    }


    //暂停 恢复 领取奖励
    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");

        claimPaused = true;

        emit PauseClaim();
    }
    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");

        claimPaused = false;

        emit UnpauseClaim();
    }

    //修改质押奖励的开始 结束区块高度
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(
            _startBlock <= endBlock,
            "start block must be smaller than end block"
        );

        startBlock = _startBlock;

        emit SetStartBlock(_startBlock);
    }
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(
            startBlock <= _endBlock,
            "start block must be smaller than end block"
        );

        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    //修改每区块的 QQQ 奖励发放量
    function setQQQPerBlock(
        uint256 _QQQPerBlock
    ) public onlyRole(ADMIN_ROLE) {
        require(_QQQPerBlock > 0, "invalid parameter");

        QQQPerBlock = _QQQPerBlock;

        emit SetQQQPerBlock(_QQQPerBlock);
    }


    /**
    * @notice 添加新的质押池
    *         允许管理员创建新的质押池，支持不同的质押代币和配置参数
    *         第一个池子必须是 ETH 池（地址为 0x0），后续池子必须是 ERC20 代币
    *
    * @param _stTokenAddress     质押代币的合约地址，如果是 ETH 则为 address(0x0)
    * @param _poolWeight         池子权重，权重越高获得的奖励分配比例越大
    * @param _minDepositAmount   最小质押数量，用户质押必须达到此数量
    * @param _unstakeLockedBlocks 解质押锁定的区块数，用户解质押后需要等待这么多区块才能提取
    * @param _withUpdate         是否在添加前先更新所有现有池子的奖励状态
    */
    function addPool(
        address _stTokenAddress,      // 质押代币地址（ETH 为 0x0，ERC20 为具体合约地址）
        uint256 _poolWeight,          // 池子权重（影响奖励分配比例）
        uint256 _minDepositAmount,    // 最小质押数量要求
        uint256 _unstakeLockedBlocks, // 解质押锁定的区块数
        bool _withUpdate              // 是否先更新所有现有池子的奖励状态
    ) public onlyRole(ADMIN_ROLE) {
        // 检查质押代币地址的有效性
        // 如果不是第一个池子（已有其他池子），则质押代币地址不能是零地址
        if (pools.length > 0) {
            require(
                _stTokenAddress != address(0x0),
                "invalid staking token address"  // 质押代币地址不能为空
            );
        } else {
            // 如果是第一个池子，必须是 ETH 池（地址为 0x0）
            require(
                _stTokenAddress == address(0x0),
                "invalid staking token address"  // 第一个池子必须是 ETH 池
            );
        }

        // 检查解质押锁定区块数必须大于 0
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");

        // 检查当前区块数必须小于活动结束区块，确保在活动结束前添加池子
        require(block.number < endBlock, "Already ended");

        // 如果需要更新现有池子的奖励状态，则先执行批量更新
        // 这样可以确保在添加新池子前，现有池子的奖励计算是准确的
        if (_withUpdate) {
            massUpdatePools();  // 更新所有现有池子的奖励状态
        }

        // 计算池子的上次奖励发放区块
        // 如果当前区块大于质押活动开始区块，则从当前区块开始计算奖励
        // 否则从质押活动开始区块开始计算奖励
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number      // 当前区块
            : startBlock;       // 活动开始区块

        // 将新池子的权重累加到总权重中
        // 这个总权重用于后续奖励分配计算
        totalPoolWeight = totalPoolWeight + _poolWeight;

        // 创建新的池子并添加到池子数组中
        pools.push(
            Pool({
                stTokenAddress: _stTokenAddress,           // 质押代币地址
                poolWeight: _poolWeight,                   // 池子权重
                lastRewardBlock: lastRewardBlock,          // 上次奖励发放的区块高度
                accQQQPerST: 0,                      // 每质押代币累积的 QQQ 数量（初始为 0）
                stTokenAmount: 0,                         // 池子中质押代币的总数量（初始为 0）
                minDepositAmount: _minDepositAmount,       // 最小质押数量要求
                unstakeLockedBlocks: _unstakeLockedBlocks  // 解质押锁定的区块数
            })
        );

        // 触发添加池子事件，记录池子创建的相关信息
        // 便于前端、监控系统等外部应用追踪池子创建情况
        emit AddPool(
            _stTokenAddress,           // 质押代币地址
            _poolWeight,               // 池子权重
            lastRewardBlock,           // 上次奖励发放区块
            _minDepositAmount,         // 最小质押数量
            _unstakeLockedBlocks       // 解质押锁定区块数
        );
    }



    /**
    * @notice 更新指定质押池的基本信息
    *         允许管理员修改现有质押池的最小质押数量和解质押锁定区块数
    *         不影响池子的核心配置如代币地址、权重等
    *
    * @param _pid                  质押池 ID，必须是有效的池子索引
    * @param _minDepositAmount     新的最小质押数量要求
    * @param _unstakeLockedBlocks  新的解质押锁定区块数
    */
    function updatePool(
        uint256 _pid,                    // 质押池 ID（数组索引）
        uint256 _minDepositAmount,       // 新的最小质押数量要求
        uint256 _unstakeLockedBlocks     // 新的解质押锁定区块数
    ) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        // 检查权限：只有拥有 ADMIN_ROLE 角色的地址可以调用
        // checkPid(_pid) 修饰器会验证 _pid 是否为有效的池子索引
        // 即 _pid < pool.length，防止数组越界

        // 更新指定池子的最小质押数量
        // 这个参数决定了用户在该池子质押时必须达到的最低数量要求
        pools[_pid].minDepositAmount = _minDepositAmount;

        // 更新指定池子的解质押锁定区块数
        // 这个参数决定了用户解质押后需要等待多少个区块才能提取资金
        pools[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;

        // 触发池子信息更新事件，记录修改详情
        // 便于前端、监控系统等外部应用追踪池子配置变化
        emit UpdatePoolInfo(
            _pid,                        // 被更新的池子 ID
            _minDepositAmount,          // 新的最小质押数量
            _unstakeLockedBlocks        // 新的解质押锁定区块数
        );
    }


    /**
 * @notice 更新指定质押池的权重
 *         允许管理员动态调整某个质押池在奖励分配中的权重
 *         权重越高，该池子获得的奖励份额越大
 *
 * @param _pid          质押池 ID，必须是有效的池子索引
 * @param _poolWeight   新的池子权重，必须大于 0
 * @param _withUpdate   是否在更新权重前先更新所有池子的奖励状态
 */
    function setPoolWeight(
        uint256 _pid,           // 质押池 ID（数组索引）
        uint256 _poolWeight,    // 新的池子权重
        bool _withUpdate        // 是否先更新所有池子的奖励状态
    ) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        // 验证新权重必须大于 0
        // 权重为 0 会导致该池子无法获得任何奖励，通常不允许
        require(_poolWeight > 0, "invalid pool weight");

        // 如果需要更新现有池子的奖励状态，则先执行批量更新
        // 这样可以确保在调整权重前，所有池子的奖励计算是准确的
        // 避免权重调整导致的奖励计算误差
        if (_withUpdate) {
            massUpdatePools();  // 更新所有现有池子的奖励状态
        }

        // 更新总权重：先减去旧权重，再加上新权重
        // 这样可以保持总权重的准确性，用于后续的奖励分配计算
        // totalPoolWeight = 之前的总权重 - 旧的池子权重 + 新的池子权重
        totalPoolWeight = totalPoolWeight - pools[_pid].poolWeight + _poolWeight;

        // 更新指定池子的权重
        // 这个权重直接影响该池子在奖励分配中的占比
        pools[_pid].poolWeight = _poolWeight;

        // 触发池子权重更新事件，记录修改详情
        // 包括：池子 ID、新的权重值、更新后的总权重
        // 便于前端、监控系统等外部应用追踪权重变化对奖励分配的影响
        emit SetPoolWeight(
            _pid,                           // 被更新的池子 ID
            _poolWeight,                    // 新的池子权重
            totalPoolWeight                 // 更新后的总权重（所有池子权重之和）
        );
    }

    //获取质押池的总个数
    function poolLength() external view returns (uint256) {
        return pools.length;
    }



    /**
     * @notice 计算指定区块区间内的奖励倍数
     *         根据区块高度差和每区块奖励数量，计算该时间段内可获得的总奖励基数
     *         用于奖励分配计算的基础函数
     *
     * @param _from    起始区块号（包含）
     * @param _to      结束区块号（不包含）
    * @return multiplier 返回指定区块区间内的奖励倍数
    *                   计算公式：(实际结束区块 - 实际起始区块) * QQQPerBlock
    */
    function getMultiplier(
        uint256 _from,    // 起始区块号（包含）
        uint256 _to       // 结束区块号（不包含）
    ) public view returns (uint256 multiplier) {
        // 验证起始区块不能大于结束区块
        // 如果 _from > _to，则区块区间无效
        require(_from <= _to, "invalid block");

        // 边界调整：如果起始区块早于质押活动开始时间，则从活动开始时间计算
        // 确保奖励计算不会在活动开始前就开始计数
        if (_from < startBlock) {
            _from = startBlock;
        }

        // 边界调整：如果结束区块晚于质押活动结束时间，则到活动结束时间停止
        // 确保奖励计算不会在活动结束后继续
        if (_to > endBlock) {
            _to = endBlock;
        }

        // 再次验证调整后的区块区间是否有效
        // 防止出现 startBlock > endBlock 的情况（比如活动已经结束）
        require(_from <= _to, "end block must be greater than start block");

        // 使用安全乘法计算奖励倍数
        // tryMul 是 OpenZeppelin 提供的安全乘法函数，防止整数溢出
        bool success;  // 乘法操作是否成功的标志
        (success, multiplier) = (_to - _from).tryMul(QQQPerBlock);

        // 验证乘法操作成功，防止溢出错误
        // 如果区块差乘以每区块奖励数量导致数值溢出，则交易失败
        require(success, "multiplier overflow");
    }


    /**
     * @notice 查询指定用户在指定质押池中的待领取奖励数量
    *         计算用户当前可以领取但尚未领取的 QQQ 奖励
    *         该函数基于当前区块高度计算用户应得奖励
    *
    * @param _pid    质押池 ID，必须是有效的池子索引
    * @param _user   用户地址，查询该用户在指定池子中的待领取奖励
    * @return uint256 返回用户可以领取的 QQQ 奖励数量
    */
    function pendingQQQ(
        uint256 _pid,      // 质押池 ID（数组索引）
        address _user      // 用户地址
    ) external view checkPid(_pid) returns (uint256) {
        // 调用内部函数 pendingQQQByBlockNumber 计算待领取奖励
        // 使用当前区块高度 block.number 作为计算基准
        // 这样可以获取用户到目前为止应得的全部奖励
        return pendingQQQByBlockNumber(_pid, _user, block.number);
    }

    /**
    * @notice 根据指定区块高度计算用户在质押池中的待领取奖励
    *         这是一个核心的奖励计算函数，用于精确计算用户应得的 QQQ 奖励
     *         考虑了用户质押量、池子权重、历史奖励等多种因素
    *
    * @param _pid         质押池 ID，必须是有效的池子索引
    * @param _user        用户地址，查询该用户在指定池子中的待领取奖励
    * @param _blockNumber 指定的区块高度，用于计算到该区块为止的奖励
    * @return uint256     返回用户可以领取的 QQQ 奖励数量
    */
    function pendingQQQByBlockNumber(
        uint256 _pid,           // 质押池 ID（数组索引）
        address _user,          // 用户地址
        uint256 _blockNumber    // 指定的区块高度
    ) public view checkPid(_pid) returns (uint256) {
        // 获取指定池子的存储引用，避免重复读取
        Pool storage pool_ = pools[_pid];

        // 获取指定用户在指定池子中的存储引用
        User storage user_ = userInfoMap[_pid][_user];

        // 获取池子的累计奖励率（每质押代币累积的 QQQ 数量）
        uint256 accQQQPerST = pool_.accQQQPerST;

        // 获取池子中的总质押代币数量
        uint256 stSupply = pool_.stTokenAmount;

        // 如果当前区块高度大于上次奖励发放区块，且池子中有质押资金
        // 则需要计算新增的奖励并更新累计奖励率
        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {
            // 计算从上次奖励发放到当前区块的奖励倍数
            // 即这段时间内应该发放的奖励基数
            uint256 multiplier = getMultiplier(
                pool_.lastRewardBlock,  // 上次奖励发放的区块
                _blockNumber           // 当前查询的区块
            );

            // 根据池子权重计算该池子应获得的奖励数量
            // 奖励按权重比例分配给不同池子
            uint256 QQQForPool = (multiplier * pool_.poolWeight) /
                        totalPoolWeight;

            // 更新池子的累计奖励率
            // 将新增奖励平均分配给池子中的所有质押代币
            // 使用 1 ether 作为精度因子，避免小数计算
            accQQQPerST =
                accQQQPerST +
                (QQQForPool * (1 ether)) /  // 乘以精度因子
                stSupply;                        // 除以质押总量，得到每代币奖励
        }

        // 计算用户总的待领取奖励，包含三个部分：
        // 1. 用户当前应得的累计奖励：用户质押量 × 累计奖励率 ÷ 精度因子
        // 2. 减去用户已经领取的奖励：user_.finishedQQQ
        // 3. 加上用户之前累积的待领取奖励：user_.pendingQQQ
        return
                (user_.stAmount * accQQQPerST) /     // 用户应得累计奖励
                (1 ether) -                               // 除以精度因子
                user_.finishedQQQ +                  // 减去已领取奖励
                user_.pendingQQQ;                    // 加上之前累积的待领取奖励
    }



    //查询指定用户在指定质押池中的质押余额
    function stakingBalance(
        uint256 _pid,      // 质押池 ID（数组索引）
        address _user      // 用户地址
    ) external view checkPid(_pid) returns (uint256) {
        return userInfoMap[_pid][_user].stAmount;
    }


    /**

     * @notice 用户已申请解质押的总数量和可提取的数量
     *         用于前端显示用户的解质押状态和可提取资金
     *
     * @param _pid    质押池 ID，必须是有效的池子索引
     * @param _user   用户地址，查询该用户在指定池子中的解质押信息
    * @return requestAmount         用户总共申请解质押的代币数量（包括可提取和待锁定的）
    * @return pendingWithdrawAmount 用户当前可以提取的代币数量（锁定期已过的申请）
    */
    function withdrawAmount(
        uint256 _pid,      // 质押池 ID（数组索引）
        address _user      // 用户地址
    )
    public
    view
    checkPid(_pid)
    returns (
        uint256 requestAmount,           // 总申请解质押数量
        uint256 pendingWithdrawAmount    // 当前可提取数量
    ) {
        // 获取指定用户在指定池子中的存储引用
        // 便于访问用户的解质押申请记录
        User storage user_ = userInfoMap[_pid][_user];

        // 遍历用户的所有解质押申请记录
        // 计算总申请数量和当前可提取数量
        for (uint256 i = 0; i < user_.requests.length; i++) {
            // 检查当前申请的解锁区块是否已到达
            // 如果 unlockBlocks <= 当前区块号，则该笔资金已解锁
            if (user_.requests[i].unlockBlocks <= block.number) {
                // 累加可提取的解质押数量
                // 这些资金的锁定期已过，用户可以立即提取
                pendingWithdrawAmount =
                    pendingWithdrawAmount +
                    user_.requests[i].amount;
            }
            // 累加总申请解质押数量（不管是否已解锁）
            // 包括正在锁定中的和已解锁的资金
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }



    /**
     * @notice 更新指定质押池的奖励状态
     *         计算并更新池子的累计奖励率，确保用户奖励计算的准确性
    *         这是质押系统中最重要的状态更新函数之一
     *
    * @param _pid    质押池 ID，必须是有效的池子索引
    */
    function updatePool(uint256 _pid) public checkPid(_pid) {
        // 获取指定池子的存储引用，便于后续操作
        Pool storage pool_ = pools[_pid];

        // 如果当前区块号小于等于上次奖励发放区块，则无需更新
        // 防止不必要的计算和状态变更
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }

        // 计算从上次奖励发放到当前区块的奖励基数
        // 使用安全乘法防止整数溢出
        (bool success1, uint256 totalQQQ) = getMultiplier(
            pool_.lastRewardBlock,  // 上次奖励发放的区块
            block.number           // 当前区块
        ).tryMul(pool_.poolWeight); // 乘以池子权重
        require(success1, "overflow");  // 检查乘法是否成功

        // 将奖励按权重比例分配给该池子
        // 总奖励 = 区间奖励 × 池子权重 ÷ 总权重
        (success1, totalQQQ) = totalQQQ.tryDiv(totalPoolWeight);
        require(success1, "overflow");  // 检查除法是否成功

        // 获取池子中的总质押代币数量
        uint256 stSupply = pool_.stTokenAmount;

        // 如果池子中有质押资金，则更新累计奖励率
        if (stSupply > 0) {
            // 将新增奖励转换为每质押代币的奖励（使用 1 ether 作为精度因子）
            (bool success2, uint256 totalQQQ_) = totalQQQ.tryMul(
                1 ether  // 精度因子，避免小数计算
            );
            require(success2, "overflow");  // 检查乘法是否成功

            // 计算每质押代币应得的奖励
            // 新增奖励率 = 新增总奖励 × 精度因子 ÷ 质押总量
            (success2, totalQQQ_) = totalQQQ_.tryDiv(stSupply);
            require(success2, "overflow");  // 检查除法是否成功

            // 将新增的奖励率加到现有的累计奖励率上
            // 使用安全加法防止整数溢出
            (bool success3, uint256 accQQQPerST) = pool_
                .accQQQPerST          // 现有的累计奖励率
                .tryAdd(totalQQQ_);   // 加上新增的奖励率
            require(success3, "overflow"); // 检查加法是否成功

            // 更新池子的累计奖励率
            pool_.accQQQPerST = accQQQPerST;
        }

        // 更新池子的最后奖励发放区块为当前区块
        // 下次更新时从此区块开始计算
        pool_.lastRewardBlock = block.number;

        // 触发池子更新事件，记录更新详情
        // 便于前端、监控系统等外部应用追踪池子状态变化
        emit UpdatePool(
            _pid,                    // 被更新的池子 ID
            pool_.lastRewardBlock,   // 更新后的最后奖励区块
            totalQQQ            // 本次更新分配给该池子的奖励数量
        );
    }


    //批量更新所有质押池的奖励状态
    function massUpdatePools() public {

        uint256 length = pools.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }


    /**
    * @notice 用户质押 ETH 的入口函数
    *         允许用户向 ETH 质押池（固定 PID 为 0）存入 ETH 代币
    *         这是专门处理原生 ETH 质押的函数，使用 payable 修饰符接收 ETH
    *
    * @dev 此函数只能在合约未暂停时调用
    *      用户需要通过发送 ETH 调用此函数
    */
    function depositETH() public payable whenNotPaused {
        // 获取 ETH 质押池的存储引用
        // ETH_PID 通常是 0，表示第一个池子是 ETH 池
        Pool storage pool_ = pools[ETH_PID];
        // 防止合约逻辑错误或配置错误
        require(
            pool_.stTokenAddress == address(0x0),
            "invalid staking token address"  // 池子不是 ETH 池
        );

        // 获取用户实际发送的 ETH 数量
        // msg.value 包含了用户调用函数时发送的 ETH 金额
        uint256 _amount = msg.value;

        // 验证质押数量是否满足最小质押要求
        // 确保用户质押的 ETH 数量不低于池子设定的最低门槛
        require(
            _amount >= pool_.minDepositAmount,
            "deposit amount is too small"  // 质押数量低于最小要求
        );

        // 调用内部通用质押函数处理具体的质押逻辑
        // 包括更新用户质押记录、计算奖励、更新池子状态等
        _deposit(ETH_PID, _amount);
    }

    /**
 * @notice 用户质押 ERC20 代币的入口函数
 *         允许用户向指定的质押池存入 ERC20 代币
 *         这是处理 ERC20 代币质押的主要函数（不包括 ETH）
 *
 * @param _pid    质押池 ID，必须是有效的非 ETH 池子索引
 * @param _amount 质押的代币数量，必须大于最小质押要求
 * @dev 此函数只能在合约未暂停时调用
 *      用户需要先授权合约使用其代币（approve 操作）
 */
    function deposit(
        uint256 _pid,      // 质押池 ID（不能是 ETH 池，即不能为 0）
        uint256 _amount    // 质押的代币数量
    ) public whenNotPaused checkPid(_pid) {
        // 验证不能向 ETH 池（PID=0）进行 ERC20 质押
        // ETH 质押需要使用 depositETH() 函数
        require(_pid != 0, "deposit not support ETH staking");

        // 获取指定池子的存储引用
        Pool storage pool_ = pools[_pid];

        // 验证质押数量必须大于最小质押要求
        // 注意：这里使用 > 而不是 >=，要求必须超过最小值
        require(
            _amount > pool_.minDepositAmount,
            "deposit amount is too small"  // 质押数量必须超过最小要求
        );

        // 如果质押数量大于 0，则执行代币转账
        // 从用户账户转移到合约账户
        if (_amount > 0) {
            // 使用安全的代币转账函数
            // IERC20 接口确保代币合约的标准兼容性
            // safeTransferFrom 从用户地址转出代币到合约地址
            IERC20(pool_.stTokenAddress).safeTransferFrom(
                msg.sender,           // 代币来源：调用者地址
                address(this),        // 代币目标：当前合约地址
                _amount               // 转账数量
            );
        }

        // 调用内部通用质押函数处理具体的质押逻辑
        // 包括更新用户质押记录、计算奖励、更新池子状态等
        _deposit(_pid, _amount);
    }


    /**
    * @notice 用户申请解质押函数
    *         允许用户申请提取部分或全部质押的代币
    *         解质押的资金需要经过锁定期后才能提取
    *
    * @param _pid    质押池 ID，必须是有效的池子索引
    * @param _amount 申请解质押的代币数量，不能超过用户的质押余额
     * @dev 此函数只能在合约未暂停且解质押未被暂停时调用
    */
    function unstake(
        uint256 _pid,      // 质押池 ID
        uint256 _amount    // 申请解质押的代币数量
    ) public whenNotPaused checkPid(_pid) whenNotWithdrawPaused {
        // 获取指定池子的存储引用
        Pool storage pool_ = pools[_pid];

        // 获取当前用户在指定池子中的存储引用
        User storage user_ = userInfoMap[_pid][msg.sender];

        // 验证用户有足够的质押余额进行解质押
        // 用户质押数量 >= 申请解质押数量
        require(user_.stAmount >= _amount, "Not enough staking token balance");

        // 更新池子的奖励状态，确保奖励计算准确
        // 这样可以正确计算用户应得的未领取奖励
        updatePool(_pid);

        // 计算用户当前应得但未领取的 QQQ 奖励
        // 公式：用户质押量 × 累计奖励率 ÷ 精度因子 - 已领取奖励
        uint256 pendingQQQ_ = (user_.stAmount * pool_.accQQQPerST) /
            (1 ether) -
                        user_.finishedQQQ;

        // 如果有未领取的奖励，则累加到用户的待领取奖励中
        if (pendingQQQ_ > 0) {
            user_.pendingQQQ = user_.pendingQQQ + pendingQQQ_;
        }

        // 如果申请解质押数量大于 0，则执行解质押操作
        if (_amount > 0) {
            // 减少用户的质押余额
            user_.stAmount = user_.stAmount - _amount;

            // 将解质押请求添加到用户的请求队列中
            // 包括解质押数量和解锁区块（当前区块 + 锁定区块数）
            user_.requests.push(
                UnstakeRequest({
                    amount: _amount,                                    // 解质押数量
                    unlockBlocks: block.number + pool_.unstakeLockedBlocks  // 解锁的区块高度
                })
            );
        }

        // 减少池子的总质押代币数量
        pool_.stTokenAmount = pool_.stTokenAmount - _amount;

        // 更新用户已领取奖励的基准值
        // 这样可以确保后续奖励计算基于新的质押量
        user_.finishedQQQ =
            (user_.stAmount * pool_.accQQQPerST) /
            (1 ether);

        // 触发解质押申请事件，记录用户的解质押行为
        emit RequestUnstake(
            msg.sender,  // 申请解质押的用户地址
            _pid,        // 质押池 ID
            _amount      // 解质押数量
        );
    }


    /**
    * @notice 用户提取已解锁解质押资金的函数
    *         允许用户提取已经达到解锁时间的解质押资金
    *         自动清理已提取的解质押请求记录
    *
    * @param _pid    质押池 ID，必须是有效的池子索引
    * @dev 此函数只能在合约未暂停且解质押未被暂停时调用
    *      用户只能提取已经过了锁定期的解质押资金
    */
    function withdraw(
        uint256 _pid      // 质押池 ID
    ) public whenNotPaused checkPid(_pid) whenNotWithdrawPaused {
        // 获取指定池子的存储引用
        Pool storage pool_ = pools[_pid];

        // 获取当前用户在指定池子中的存储引用
        User storage user_ = userInfoMap[_pid][msg.sender];

        // 声明变量用于记录可提取金额和需要移除的请求数量
        uint256 pendingWithdraw_;  // 当前可提取的总金额
        uint256 popNum_;           // 已解锁的解质押请求数量

        // 遍历用户的所有解质押请求，查找已解锁的请求
        for (uint256 i = 0; i < user_.requests.length; i++) {
            // 如果当前请求的解锁区块仍大于当前区块，则后续请求也未解锁，跳出循环
            if (user_.requests[i].unlockBlocks > block.number) {
                break;
            }
            // 累加已解锁请求的金额
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            // 记录已解锁的请求数量
            popNum_++;
        }

        // 重新排列请求数组，将未解锁的请求移到前面
        // 这是手动实现的数组元素前移操作
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            // 将未解锁的请求向前移动 popNum_ 个位置
            user_.requests[i] = user_.requests[i + popNum_];
        }

        // 移除数组末尾已提取的请求记录
        // popNum_ 代表有多少个已解锁的请求需要移除
        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();  // 弹出数组最后一个元素
        }

        // 如果有可提取的金额，则执行转账操作
        if (pendingWithdraw_ > 0) {
            // 根据质押代币类型选择不同的转账方式
            if (pool_.stTokenAddress == address(0x0)) {
                // 如果是 ETH 池，使用安全的 ETH 转账
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                // 如果是 ERC20 池，使用安全的 ERC20 转账
                IERC20(pool_.stTokenAddress).safeTransfer(
                    msg.sender,          // 转账目标：用户地址
                    pendingWithdraw_     // 转账数量：可提取金额
                );
            }
        }

        // 触发提取事件，记录用户的提取行为
        emit Withdraw(
            msg.sender,              // 提取资金的用户地址
            _pid,                    // 质押池 ID
            pendingWithdraw_,        // 提取的金额
            block.number             // 提取时的区块高度
        );
    }


    /**
    * @notice 用户领取质押奖励的函数
    *         允许用户领取在指定质押池中获得的 QQQ 奖励
    *         计算并转移用户应得的全部奖励到用户账户
    *
    * @param _pid    质押池 ID，必须是有效的池子索引
    * @dev 此函数只能在合约未暂停且领取功能未被暂停时调用
    *      用户只能领取已累积但未领取的奖励
    */
    function claim(
        uint256 _pid      // 质押池 ID
    ) public whenNotPaused checkPid(_pid) whenNotClaimPaused {
        // 获取指定池子的存储引用
        Pool storage pool_ = pools[_pid];

        // 获取当前用户在指定池子中的存储引用
        User storage user_ = userInfoMap[_pid][msg.sender];

        // 更新池子的奖励状态，确保奖励计算基于最新状态
        // 这样可以获取到当前时刻用户应得的准确奖励数量
        updatePool(_pid);

        // 计算用户当前应领取的 QQQ 奖励总额
        // 包含三个部分：
        // 1. 用户当前质押量 × 累计奖励率 ÷ 精度因子 - 已领取奖励（新产生的奖励）
        // 2. 用户之前累积的待领取奖励（user_.pendingQQQ）
        uint256 pendingQQQ_ = (user_.stAmount * pool_.accQQQPerST) /
            (1 ether) -                       // 用户当前应得奖励
                        user_.finishedQQQ +              // 减去已领取部分
                        user_.pendingQQQ;                // 加上之前累积的待领取奖励

        // 如果有可领取的奖励，则执行转账操作
        if (pendingQQQ_ > 0) {
            // 清零用户的待领取奖励记录
            // 因为即将全部转账给用户
            user_.pendingQQQ = 0;

            // 向用户地址安全转账 QQQ 奖励
            _safeQQQTransfer(msg.sender, pendingQQQ_);
        }

        // 更新用户已领取奖励的基准值
        // 这样下次计算奖励时会基于新的基准，避免重复计算
        user_.finishedQQQ =
            (user_.stAmount * pool_.accQQQPerST) /  // 用户当前质押量 × 累计奖励率
            (1 ether);                                   // 除以精度因子

        // 触发领取事件，记录用户的领取行为
        emit Claim(
            msg.sender,              // 领取奖励的用户地址
            _pid,                    // 质押池 ID
            pendingQQQ_         // 领取的奖励数量
        );
    }


    /**
 * @notice 内部质押处理函数
 *         处理用户的质押逻辑，包括奖励计算、状态更新等
 *         这是一个内部函数，被 depositETH 和 deposit 函数调用
 *
 * @param _pid    质押池 ID，必须是有效的池子索引
 * @param _amount 质押的代币数量
 * @dev 此函数包含完整的质押处理逻辑，包括奖励计算和状态同步
 */
    function _deposit(uint256 _pid, uint256 _amount) internal {
        // 获取指定池子的存储引用
        Pool storage pool_ = pools[_pid];

        // 获取当前用户在指定池子中的存储引用
        User storage user_ = userInfoMap[_pid][msg.sender];

        // 更新池子的奖励状态，确保奖励计算基于最新状态
        // 这样可以准确计算用户应得的未领取奖励
        updatePool(_pid);

        // 如果用户之前有质押记录，则计算并累积未领取的奖励
        if (user_.stAmount > 0) {
            // 计算用户当前应得的累计奖励（使用安全乘法防止溢出）
            // 公式：用户质押量 × 累计奖励率 ÷ 精度因子
            (bool success1, uint256 accST) = user_.stAmount.tryMul(
                pool_.accQQQPerST  // 用户质押量 × 累计奖励率
            );
            require(success1, "user stAmount mul accQQQPerST overflow");  // 检查乘法溢出

            (success1, accST) = accST.tryDiv(1 ether);  // 除以精度因子
            require(success1, "accST div 1 ether overflow");  // 检查除法溢出

            // 计算用户当前应领取但未领取的奖励
            // 公式：累计应得奖励 - 已领取奖励
            (bool success2, uint256 pendingQQQ_) = accST.trySub(
                user_.finishedQQQ  // 从累计应得中减去已领取部分
            );
            require(success2, "accST sub finishedQQQ overflow");  // 检查减法溢出

            // 如果有待领取的奖励，则累加到用户的待领取奖励中
            if (pendingQQQ_ > 0) {
                // 将新产生的奖励加到之前的待领取奖励上
                (bool success3, uint256 _pendingQQQ) = user_
                    .pendingQQQ
                    .tryAdd(pendingQQQ_);  // 累积奖励
                require(success3, "user pendingQQQ overflow");  // 检查加法溢出
                user_.pendingQQQ = _pendingQQQ;  // 更新待领取奖励
            }
        }

        // 如果质押数量大于 0，则更新用户的质押余额
        if (_amount > 0) {
            // 安全地增加用户的质押数量
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");  // 检查加法溢出
            user_.stAmount = stAmount;  // 更新用户质押余额
        }

        // 增加池子的总质押代币数量
        // 安全地增加池子的总质押量
        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(
            _amount  // 增加质押数量
        );
        require(success5, "pool stTokenAmount overflow");  // 检查加法溢出
        pool_.stTokenAmount = stTokenAmount;  // 更新池子总质押量

        // 更新用户已领取奖励的基准值
        // 这样可以确保后续奖励计算基于新的质押量
        // 公式：用户当前质押量 × 累计奖励率 ÷ 精度因子
        (bool success6, uint256 finishedQQQ) = user_.stAmount.tryMul(
            pool_.accQQQPerST  // 用户当前质押量 × 累计奖励率
        );
        require(success6, "user stAmount mul accQQQPerST overflow");  // 检查乘法溢出

        (success6, finishedQQQ) = finishedQQQ.tryDiv(1 ether);  // 除以精度因子
        require(success6, "finishedQQQ div 1 ether overflow");  // 检查除法溢出

        user_.finishedQQQ = finishedQQQ;  // 更新已领取奖励基准

        // 触发质押事件，记录用户的质押行为
        emit Deposit(
            msg.sender,  // 质押的用户地址
            _pid,        // 质押池 ID
            _amount      // 质押的数量
        );
    }


    /**
     * @notice 安全的 QQQ 代币转账函数
    *         用于向用户安全转账 QQQ 奖励
    *         防止合约 QQQ 余额不足导致转账失败
    *
    * @param _to     接收地址，QQQ 奖励的接收方
    * @param _amount 转账数量，希望转账的 QQQ 数量
    * @dev 这是一个内部函数，主要用于 claim 函数中的奖励发放
    *      确保即使合约余额不足也能安全转账
    */
    function _safeQQQTransfer(address _to, uint256 _amount) internal {
        // 获取合约当前持有的 QQQ 代币余额
        // 这是合约实际可用的 QQQ 数量
        uint256 QQQBal = QQQ.balanceOf(address(this));
        // 检查希望转账的数量是否超过合约的实际余额
        if (_amount > QQQBal) {
            // 如果转账数量超过合约余额，则只转账合约的全部余额
            // 这样可以避免转账失败，确保用户至少能收到部分奖励
            QQQ.transfer(_to, QQQBal);
        } else {
            // 如果合约余额充足，则转账指定数量
            // 这是最常见的情况，转账成功完成
            QQQ.transfer(_to, _amount);
        }
    }

    /**
    * @notice 安全的 ETH 转账函数
    *         用于向用户安全转账 ETH（主要是 ETH 池的解质押资金）
    *         使用 call 方法进行转账，避免重入攻击并确保转账成功
    *
    * @param _to     接收地址，ETH 的接收方
    * @param _amount 转账数量，希望转账的 ETH 数量（以 wei 为单位）
    * @dev 这是一个内部函数，主要用于 withdraw 函数中的 ETH 提取
    *      使用 call 方法比 transfer 更安全，可以防止重入攻击
    */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        // 使用 call 方法进行 ETH 转账
        // call 是底层函数，相比 transfer 更灵活且可以防止重入攻击
        (bool success, bytes memory data) = address(_to).call{value: _amount}(
            ""  // 空的 calldata，因为我们只是转账 ETH，不需要调用合约函数
        );

        // 验证转账操作是否成功
        // 如果 call 失败，交易会回滚
        require(success, "ETH transfer call failed");

        // 如果返回数据长度大于 0，说明接收方是合约地址
        // 需要检查合约执行的结果
        if (data.length > 0) {
            // 解码返回的数据，期望是布尔值
            // 如果合约执行失败，会返回 false，导致交易回滚
            require(
                abi.decode(data, (bool)),  // 将返回数据解码为布尔值
                "ETH transfer operation did not succeed"  // 解码后的值为 false 时的错误信息
            );
        }
    }
}
