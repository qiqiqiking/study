package singlenumber

// SingleNumber 任何数和自己异或，结果是 0。任何数和 0 异或，结果是它自己。
func SingleNumber(nums []int) int {
	single := 0
	for _, num := range nums {
		single ^= num
	}
	return single
}
