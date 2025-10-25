-- 1. 插入数据
INSERT INTO students (name, age, grade) VALUES ('张三', 20, '三年级');

-- 2. 查询年龄 > 18 的学生
SELECT * FROM students WHERE age > 18;
-- 结果: 张三 | 20 | 三年级

-- 3. 更新张三的年级
UPDATE students SET grade = '四年级' WHERE name = '张三';

-- 4. 删除年龄 < 15 的学生
DELETE FROM students WHERE age < 15;