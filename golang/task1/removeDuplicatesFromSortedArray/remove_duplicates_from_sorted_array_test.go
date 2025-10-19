package removeDuplicatesFromSortedArray

import (
	"reflect"
	"testing"
)

func TestRemoveDuplicates(t *testing.T) {
	tests := []struct {
		name     string
		input    []int
		expected []int // 前 k 个元素
		k        int
	}{
		{"基本案例", []int{1, 1, 2}, []int{1, 2}, 2},
		{"多个重复", []int{0, 0, 1, 1, 1, 2, 2, 3, 3, 4}, []int{0, 1, 2, 3, 4}, 5},
		{"无重复", []int{1, 2, 3}, []int{1, 2, 3}, 3},
		{"全相同", []int{1, 1, 1, 1}, []int{1}, 1},
		{"单元素", []int{1}, []int{1}, 1},
		{"空数组", []int{}, []int{}, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// 传入副本，避免修改原始测试数据
			nums := make([]int, len(tt.input))
			copy(nums, tt.input)

			k := removeDuplicates(nums)

			if k != tt.k {
				t.Errorf("removeDuplicates(%v) returned k=%d, expected %d", tt.input, k, tt.k)
			}

			if !reflect.DeepEqual(nums[:k], tt.expected) {
				t.Errorf("removeDuplicates(%v) modified nums to %v (first %d), expected %v",
					tt.input, nums[:k], k, tt.expected)
			}
		})
	}
}
