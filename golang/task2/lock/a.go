package main

import (
	"fmt"
	"sync"
)

func main() {
	var counter int
	var mutex sync.Mutex
	var wg sync.WaitGroup
	numGoroutines := 10
	wg.Add(numGoroutines)
	for i := 0; i < numGoroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < 1000; j++ {
				//mutex.Lock()
				counter++
				//mutex.Unlock()
			}
		}()
	}
	wg.Wait()
	fmt.Printf("No lock final counter value: %d\n", counter)

	counter = 0
	wg.Add(numGoroutines)
	for i := 0; i < numGoroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < 1000; j++ {
				mutex.Lock()
				counter++
				mutex.Unlock()
			}
		}()
	}
	wg.Wait()
	fmt.Printf("Have lock final counter value: %d\n", counter)
}
