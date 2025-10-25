package main

import "fmt"

// Person 人
type Person struct {
	Name string
	Age  int
}

// Employee 员工
type Employee struct {
	Person
	EmployeeID string
}

// PrintInfo 打印信息
func (e Employee) PrintInfo() {
	fmt.Printf("Employee ID: %s\n", e.EmployeeID)
	fmt.Printf("Name: %s\n", e.Name)
	fmt.Printf("Age: %d\n", e.Age)
}

func main() {
	person := Person{
		Name: "Yueqi Wu",
		Age:  18,
	}
	employee := Employee{
		Person:     person,
		EmployeeID: "E12138",
	}

	employee.PrintInfo()
}
