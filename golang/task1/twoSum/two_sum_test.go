package main

import (
	"reflect"
	"testing"
)

func TestTwoSum(t *testing.T) {
	tests := []struct {
		name     string
		nums     []int
		target   int
		expected []int
	}{
		{
			name:     "基本案例",
			nums:     []int{2, 7, 11, 15},
			target:   9,
			expected: []int{0, 1},
		},
		{
			name:     "包含负数",
			nums:     []int{3, 2, 4},
			target:   6,
			expected: []int{1, 2},
		},
		{
			name:     "两个相同元素",
			nums:     []int{3, 3},
			target:   6,
			expected: []int{0, 1},
		},
		{
			name:     "包含负数和零",
			nums:     []int{-1, -2, -3, -4, -5},
			target:   -8,
			expected: []int{2, 4}, // -3 + (-5) = -8
		},
		{
			name:     "目标为零",
			nums:     []int{-3, 4, 3, 90},
			target:   0,
			expected: []int{0, 2}, // -3 + 3 = 0
		},
		{
			name:     "最小输入（两个元素）",
			nums:     []int{1, 2},
			target:   3,
			expected: []int{0, 1},
		},
		{
			name:     "大数测试",
			nums:     []int{1000000000, 2000000000, 3000000000},
			target:   3000000000,
			expected: []int{0, 1}, // 1e9 + 2e9 = 3e9
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := twoSum(tt.nums, tt.target)
			if !reflect.DeepEqual(result, tt.expected) {
				t.Errorf("twoSum(%v, %d) = %v, expected %v", tt.nums, tt.target, result, tt.expected)
			}
		})
	}
}

// TestTwoSumNoSolution 测试无解情况（虽然题目保证有解，但函数应安全处理）
func TestTwoSumNoSolution(t *testing.T) {
	result := twoSum([]int{1, 2, 3}, 10)
	if result != nil {
		t.Errorf("Expected nil for no solution, got %v", result)
	}
}
