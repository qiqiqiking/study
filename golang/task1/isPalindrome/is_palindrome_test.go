package isPalindrome

import "testing"

func TestIsPalindrome(t *testing.T) {
	tests := []struct {
		name     string
		x        int
		expected bool
	}{
		{"正回文", 121, true},
		{"负数", -121, false},
		{"末尾为0", 10, false},
		{"单数字", 0, true},
		{"单数字正数", 5, true},
		{"偶数位回文", 1221, true},
		{"奇数位回文", 12321, true},
		{"非回文", 123, false},
		{"大回文数", 123454321, true},
		{"大非回文", 123456, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isPalindrome(tt.x); got != tt.expected {
				t.Errorf("isPalindrome(%d) = %v, expected %v", tt.x, got, tt.expected)
			}
		})
	}
}
