package validParentheses

func isValid(s string) bool {
	// 用 map 建立右括号到左括号的映射，方便快速查找匹配
	pairs := map[rune]rune{
		')': '(',
		'}': '{',
		']': '[',
	}

	// 用切片模拟栈（Go 没有内置栈）
	stack := []rune{}

	// 遍历字符串中的每个字符
	for _, char := range s {
		// 如果是右括号
		if left, exists := pairs[char]; exists {
			// 栈为空，说明没有对应的左括号
			if len(stack) == 0 {
				return false
			}
			// 弹出栈顶元素（最后一个元素）
			top := stack[len(stack)-1]
			stack = stack[:len(stack)-1]

			// 检查是否匹配
			if top != left {
				return false
			}
		} else {
			// 是左括号，压入栈
			stack = append(stack, char)
		}
	}

	// 最后栈必须为空，否则有未闭合的左括号
	return len(stack) == 0
}
