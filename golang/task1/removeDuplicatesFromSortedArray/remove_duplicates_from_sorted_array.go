package removeDuplicatesFromSortedArray

func removeDuplicates(nums []int) int {
	if len(nums) == 0 {
		return 0
	}

	slow := 0 // 慢指针：指向新数组的最后一个有效位置
	for fast := 1; fast < len(nums); fast++ {
		// 如果 fast 指向的元素与 slow 不同，说明是新的唯一元素
		if nums[fast] != nums[slow] {
			slow++
			nums[slow] = nums[fast] // 写入新位置
		}
	}

	return slow + 1 // 新长度 = 索引 + 1
}
