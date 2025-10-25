-- 开始事务
START TRANSACTION;

-- 1. 检查账户A余额是否足够（使用 FOR UPDATE 锁定账户A行，防止并发修改）
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;

-- 假设查询结果为 200（足够转账）
-- 如果余额 < 100，执行回滚
-- 这里应通过应用程序逻辑判断

-- 2. 更新账户A（扣100）
UPDATE accounts SET balance = balance - 100 WHERE id = 1;

-- 3. 更新账户B（加100）
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

-- 4. 记录转账信息
INSERT INTO transactions (from_account_id, to_account_id, amount)
VALUES (1, 2, 100);

-- 提交事务（所有操作生效）
COMMIT;