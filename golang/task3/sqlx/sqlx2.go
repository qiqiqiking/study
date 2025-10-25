package main

import (
	"fmt"
	"log"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

type Book struct {
	ID     int     `db:"id"`
	Title  string  `db:"title"`
	Author string  `db:"author"`
	Price  float64 `db:"price"`
}

func main() {
	// 假的账户密码，只举例
	db, err := sqlx.Connect("mysql", "user:password@/library_db")
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	defer db.Close()

	// 执行复杂查询：价格 > 50 元的书籍
	books, err := getBooksAbovePrice(db, 50.0)
	if err != nil {
		log.Fatalf("查询书籍失败: %v", err)
	}

	// 打印结果
	fmt.Println("价格高于 50 元的书籍:")
	for _, book := range books {
		fmt.Printf("- %s by %s ($%.2f)\n", book.Title, book.Author, book.Price)
	}
}

// getBooksAbovePrice 查询价格高于指定金额的书籍
func getBooksAbovePrice(db *sqlx.DB, minPrice float64) ([]Book, error) {
	var books []Book

	// 使用参数化查询（类型安全且防SQL注入）
	err := db.Select(&books, `
		SELECT id, title, author, price 
		FROM books 
		WHERE price > ? 
		ORDER BY price DESC
	`, minPrice)

	if err != nil {
		return nil, err
	}
	return books, nil
}
