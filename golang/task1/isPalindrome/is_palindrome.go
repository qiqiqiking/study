package isPalindrome

func isPalindrome(x int) bool {
	// 负数不是回文数（因为有负号）
	// 以 0 结尾但不是 0 的数也不是回文数（如 10, 100）
	if x < 0 || (x%10 == 0 && x != 0) {
		return false
	}

	reversed := 0
	// 只反转后半部分数字，与前半部分比较
	for x > reversed {
		reversed = reversed*10 + x%10
		x /= 10
	}

	// 当数字长度为奇数时，中间的数字可以忽略（如 12321 → 比较 12 和 12）
	return x == reversed || x == reversed/10
}
