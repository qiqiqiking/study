package main

import (
	"fmt"
	"sync"
)

func main() {
	nums := make(chan int)
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		for i := 1; i <= 10; i++ {
			fmt.Printf("生产者发送: %d\n", i)
			nums <- i
		}
		close(nums)
	}()
	go func() {
		defer wg.Done()
		for num := range nums {
			fmt.Printf("消费者接收: %d\n", num)
		}
	}()
	wg.Wait()
	fmt.Println("所有任务完成")
}
