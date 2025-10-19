package mergeIntervals

import "sort"

func merge(intervals [][]int) [][]int {
	if len(intervals) == 0 {
		return nil
	}

	// 第一步：按每个区间的起始位置升序排序
	sort.Slice(intervals, func(i, j int) bool {
		return intervals[i][0] < intervals[j][0]
	})

	// 第二步：初始化结果，加入第一个区间
	merged := [][]int{intervals[0]}

	// 第三步：遍历剩余区间，尝试合并
	for i := 1; i < len(intervals); i++ {
		current := intervals[i]
		last := merged[len(merged)-1]

		// 如果当前区间的 start <= 上一个区间的 end → 重叠
		if current[0] <= last[1] {
			// 合并：更新 end 为两者最大值
			last[1] = max(last[1], current[1])
		} else {
			// 不重叠，直接加入
			merged = append(merged, current)
		}
	}

	return merged
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
