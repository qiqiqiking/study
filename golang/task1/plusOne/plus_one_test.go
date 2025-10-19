package plusOne

import (
	"reflect"
	"testing"
)

func TestPlusOne(t *testing.T) {
	tests := []struct {
		name     string
		digits   []int
		expected []int
	}{
		{"普通加一", []int{1, 2, 3}, []int{1, 2, 4}},
		{"末尾进位", []int{4, 3, 2, 1}, []int{4, 3, 2, 2}},
		{"单个9", []int{9}, []int{1, 0}},
		{"多个9", []int{9, 9}, []int{1, 0, 0}},
		{"全9", []int{9, 9, 9}, []int{1, 0, 0, 0}},
		{"中间进位", []int{8, 9, 9}, []int{9, 0, 0}},
		{"无进位", []int{1, 2, 9}, []int{1, 3, 0}},
		{"最大位进位", []int{1, 9, 9}, []int{2, 0, 0}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// 注意：plusOne 可能修改原数组，所以传副本
			input := make([]int, len(tt.digits))
			copy(input, tt.digits)
			got := plusOne(input)
			if !reflect.DeepEqual(got, tt.expected) {
				t.Errorf("plusOne(%v) = %v, expected %v", tt.digits, got, tt.expected)
			}
		})
	}
}
