package longestCommonPrefix

import "testing"

// 无需修改测试！同一个测试集适用于所有正确实现
func TestLongestCommonPrefix(t *testing.T) {
	tests := []struct {
		name     string
		strs     []string
		expected string
	}{
		{"基本案例", []string{"flower", "flow", "flight"}, "fl"},
		{"无公共前缀", []string{"dog", "racecar", "car"}, ""},
		{"单个字符串", []string{"hello"}, "hello"},
		{"空数组", []string{}, ""},
		{"包含空字符串", []string{"", "abc"}, ""},
		{"完全相同", []string{"test", "test", "test"}, "test"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := longestCommonPrefix(tt.strs); got != tt.expected {
				t.Errorf("longestCommonPrefix(%v) = %q, expected %q", tt.strs, got, tt.expected)
			}
		})
	}
}
