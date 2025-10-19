package validParentheses

import "testing"

func TestIsValid(t *testing.T) {
	tests := []struct {
		name     string
		s        string
		expected bool
	}{
		{"简单匹配", "()", true},
		{"嵌套匹配", "({[]})", true},
		{"并列匹配", "()[]{}", true},
		{"错误类型", "(]", false},
		{"交叉不匹配", "([)]", false},
		{"只有左括号", "(((", false},
		{"只有右括号", ")))", false},
		{"空字符串", "", true},
		{"单个左括号", "{", false},
		{"单个右括号", "}", false},
		{"复杂有效", "{[()]}", true},
		{"复杂无效", "{[(])}", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isValid(tt.s); got != tt.expected {
				t.Errorf("isValid(%q) = %v, expected %v", tt.s, got, tt.expected)
			}
		})
	}
}
