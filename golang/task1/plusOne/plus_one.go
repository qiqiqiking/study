package plusOne

func plusOne(digits []int) []int {
	n := len(digits)

	// 从最低位（最右边）开始加 1
	for i := n - 1; i >= 0; i-- {
		if digits[i] < 9 {
			// 当前位不是 9，直接加 1 并返回
			digits[i]++
			return digits
		}
		// 当前位是 9，置为 0，继续向高位进位
		digits[i] = 0
	}

	// 如果所有位都是 9（如 [9,9,9]），则结果是 [1,0,0,...,0]
	// 需要新建一个长度为 n+1 的数组
	result := make([]int, n+1)
	result[0] = 1
	return result
}
