package main

import (
	"fmt"
	"sync"
	"time"
)

// Task 是任务函数类型
type Task func() error

// TaskResult 表示任务执行结果
type TaskResult struct {
	Name     string
	Duration time.Duration
	Error    error
}

// Scheduler 是任务调度器
type Scheduler struct {
	tasks   []Task
	names   []string
	results chan TaskResult
	wg      sync.WaitGroup
}

// NewScheduler 创建一个新的调度器
func NewScheduler() *Scheduler {
	return &Scheduler{
		results: make(chan TaskResult, 100), // 通道缓冲区大小设为100
	}
}

// AddTask 添加一个任务，可以指定任务名称
func (s *Scheduler) AddTask(name string, task Task) {
	s.tasks = append(s.tasks, task)
	s.names = append(s.names, name)
}

// Start 开始执行所有任务
func (s *Scheduler) Start() {
	for i, task := range s.tasks {
		s.wg.Add(1)
		go func(name string, t Task) {
			start := time.Now()
			defer func() {
				if r := recover(); r != nil {
					s.results <- TaskResult{Name: name, Duration: time.Since(start), Error: fmt.Errorf("panic: %v", r)}
				}
				s.wg.Done()
			}()
			err := t()
			duration := time.Since(start)
			s.results <- TaskResult{Name: name, Duration: duration, Error: err}
		}(s.names[i], task)
	}
	s.wg.Wait()
	close(s.results)
}

// GetResults 获取所有任务执行结果
func (s *Scheduler) GetResults() []TaskResult {
	var results []TaskResult
	for result := range s.results {
		results = append(results, result)
	}
	return results
}

func main() {
	scheduler := NewScheduler()
	scheduler.AddTask("Task 1", func() error {
		fmt.Println("Starting task 1")
		time.Sleep(300 * time.Millisecond)
		fmt.Println("Completed task 1")
		return nil
	})
	scheduler.AddTask("Task 2", func() error {
		fmt.Println("Starting task 2")
		time.Sleep(500 * time.Millisecond)
		fmt.Println("Completed task 2")
		return nil
	})
	scheduler.AddTask("Task 3", func() error {
		fmt.Println("Starting task 3")
		time.Sleep(200 * time.Millisecond)
		fmt.Println("Completed task 3")
		return nil
	})
	scheduler.AddTask("Task 4", func() error {
		fmt.Println("Starting task 4")
		panic("Something went wrong!")
		return nil
	})
	scheduler.Start()
	results := scheduler.GetResults()
	fmt.Println("\nTask Execution Results:")
	for _, result := range results {
		fmt.Printf("Task %s: %v, Error: %v\n", result.Name, result.Duration, result.Error)
	}
}
