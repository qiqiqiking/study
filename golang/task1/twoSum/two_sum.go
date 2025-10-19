package twoSum

// twoSum 在整数数组 nums 中找出两个数，使它们的和等于 target，
// 并返回这两个数的下标（按出现顺序）。
// 假设每组输入有且仅有一个有效解，且不能重复使用同一个元素。
func twoSum(nums []int, target int) []int {
	// 创建一个哈希表（map），用于存储已经遍历过的数值及其对应的下标
	// key: 数组中的值，value: 该值在数组中的下标
	seen := make(map[int]int)
	// 遍历数组，k 是当前元素的下标，v 是当前元素的值
	for k, v := range nums {
		complement := target - v
		// 检查这个补数是否已经在 seen 中（即之前出现过）
		if idx, ok := seen[complement]; ok {
			// 如果存在，说明找到了答案：
			// idx 是补数的下标（较早出现），k 是当前元素的下标
			return []int{idx, k}
		}
		// 将当前元素的值和下标存入哈希表，供后续元素查找使用
		// 注意：这一步必须放在检查之后，避免同一个元素被使用两次
		seen[v] = k
	}
	// 理论上不会执行到这里（题目保证有唯一解）
	return nil
}
