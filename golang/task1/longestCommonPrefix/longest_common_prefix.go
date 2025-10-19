package longestCommonPrefix

// longestCommonPrefix 返回字符串数组的最长公共前缀
// 时间复杂度：O(S)，S 为所有字符串字符总数（最坏）
// 最佳情况：O(N)，N 为字符串个数（第一个字符就不匹配）
func longestCommonPrefix(strs []string) string {
	if len(strs) == 0 {
		return ""
	}

	// 以第一个字符串的长度为上限（公共前缀不可能比它长）
	for i := 0; i < len(strs[0]); i++ {
		char := strs[0][i] // 当前列的基准字符

		// 检查其余所有字符串的第 i 个字符
		for j := 1; j < len(strs); j++ {
			// 如果当前字符串太短，或字符不匹配 → 立即返回
			if i >= len(strs[j]) || strs[j][i] != char {
				return strs[0][:i]
			}
		}
	}

	// 第一个字符串本身就是公共前缀
	return strs[0]
}
