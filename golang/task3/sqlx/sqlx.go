package main

import (
	"fmt"
	"log"

	_ "github.com/go-sql-driver/mysql" // MySQL驱动
	"github.com/jmoiron/sqlx"
)

type Employee struct {
	ID         int    `db:"id"`
	Name       string `db:"name"`
	Department string `db:"department"`
	Salary     int    `db:"salary"`
}

func main() {
	// 假的账户密码，只举例
	db, err := sqlx.Connect("mysql", "user:password@/company_db")
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	defer db.Close()

	// 1. 查询技术部员工
	techEmployees, err := getTechDepartmentEmployees(db)
	if err != nil {
		log.Fatalf("查询技术部员工失败: %v", err)
	}
	fmt.Println("技术部员工列表:")
	for _, emp := range techEmployees {
		fmt.Printf("- %s (ID: %d, 薪水: %d)\n", emp.Name, emp.ID, emp.Salary)
	}

	// 2. 查询工资最高的员工
	highestPaidEmployee, err := getHighestPaidEmployee(db)
	if err != nil {
		log.Fatalf("查询最高薪资员工失败: %v", err)
	}
	fmt.Printf("\n最高薪资员工: %s (ID: %d, 薪水: %d)\n",
		highestPaidEmployee.Name,
		highestPaidEmployee.ID,
		highestPaidEmployee.Salary)
}

// 查询技术部员工
func getTechDepartmentEmployees(db *sqlx.DB) ([]Employee, error) {
	var employees []Employee
	err := db.Select(&employees, `
		SELECT id, name, department, salary 
		FROM employees 
		WHERE department = '技术部'
	`)
	if err != nil {
		return nil, err
	}
	return employees, nil
}

// 查询工资最高的员工
func getHighestPaidEmployee(db *sqlx.DB) (Employee, error) {
	var employee Employee
	err := db.Get(&employee, `
		SELECT id, name, department, salary 
		FROM employees 
		ORDER BY salary DESC 
		LIMIT 1
	`)
	if err != nil {
		return Employee{}, err
	}
	return employee, nil
}
