package main

import "fmt"

func addTen(p *int) {
	*p += 10
}
func main() {
	num := 5
	addTen(&num)
	fmt.Println(num)
}
