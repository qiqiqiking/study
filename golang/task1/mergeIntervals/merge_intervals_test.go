package mergeIntervals

import (
	"reflect"
	"testing"
)

func TestMerge(t *testing.T) {
	tests := []struct {
		name     string
		input    [][]int
		expected [][]int
	}{
		{
			name:     "基本合并",
			input:    [][]int{{1, 3}, {2, 6}, {8, 10}, {15, 18}},
			expected: [][]int{{1, 6}, {8, 10}, {15, 18}},
		},
		{
			name:     "完全重叠",
			input:    [][]int{{1, 4}, {4, 5}},
			expected: [][]int{{1, 5}},
		},
		{
			name:     "无重叠",
			input:    [][]int{{1, 2}, {3, 4}, {5, 6}},
			expected: [][]int{{1, 2}, {3, 4}, {5, 6}},
		},
		{
			name:     "嵌套区间",
			input:    [][]int{{1, 10}, {2, 3}, {4, 5}},
			expected: [][]int{{1, 10}},
		},
		{
			name:     "单个区间",
			input:    [][]int{{1, 2}},
			expected: [][]int{{1, 2}},
		},
		{
			name:     "空输入",
			input:    [][]int{},
			expected: [][]int(nil),
		},
		{
			name:     "乱序输入",
			input:    [][]int{{2, 3}, {1, 2}, {4, 5}},
			expected: [][]int{{1, 3}, {4, 5}},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// 深拷贝输入，避免排序污染原始数据
			input := make([][]int, len(tt.input))
			for i, v := range tt.input {
				input[i] = make([]int, len(v))
				copy(input[i], v)
			}

			got := merge(input)
			if !reflect.DeepEqual(got, tt.expected) {
				t.Errorf("merge(%v) = %v, expected %v", tt.input, got, tt.expected)
			}
		})
	}
}
