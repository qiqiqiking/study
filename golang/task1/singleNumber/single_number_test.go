package singlenumber

import "testing"

func TestSingleNumber(t *testing.T) {
	tests := []struct {
		name     string
		nums     []int
		expected int
	}{
		{
			name:     "基本案例",
			nums:     []int{2, 2, 1},
			expected: 1,
		},
		{
			name:     "唯一元素在开头",
			nums:     []int{4, 1, 2, 1, 2},
			expected: 4,
		},
		{
			name:     "唯一元素在末尾",
			nums:     []int{1, 1, 2, 2, 3},
			expected: 3,
		},
		{
			name:     "只有一个元素",
			nums:     []int{42},
			expected: 42,
		},
		{
			name:     "包含负数",
			nums:     []int{-1, -1, -2, -2, -3},
			expected: -3,
		},
		{
			name:     "包含零",
			nums:     []int{0, 1, 1},
			expected: 0,
		},
		{
			name:     "大数测试",
			nums:     []int{1000000, 2000000, 1000000},
			expected: 2000000,
		},
		{
			name:     "顺序打乱",
			nums:     []int{5, 3, 4, 3, 4, 5, 9},
			expected: 9,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SingleNumber(tt.nums)
			if got != tt.expected {
				t.Errorf("SingleNumber(%v) = %d, expected %d", tt.nums, got, tt.expected)
			}
		})
	}
}
