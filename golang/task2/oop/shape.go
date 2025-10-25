package main

import (
	"fmt"
	"math"
)

// Shape 接口定义了所有形状必须实现的方法
type Shape interface {
	Area() float64
	Perimeter() float64
}

// Rectangle 结构体表示矩形
type Rectangle struct {
	Width  float64
	Height float64
}

// Area 实现 Shape 接口，计算矩形面积
func (r Rectangle) Area() float64 {
	return r.Width * r.Height
}

// Perimeter 实现 Shape 接口，计算矩形周长
func (r Rectangle) Perimeter() float64 {
	return 2 * (r.Width + r.Height)
}

// Circle 结构体表示圆形
type Circle struct {
	Radius float64
}

// Area 实现 Shape 接口，计算圆形面积
func (c Circle) Area() float64 {
	return math.Pi * c.Radius * c.Radius
}

// Perimeter 实现 Shape 接口，计算圆形周长
func (c Circle) Perimeter() float64 {
	return 2 * math.Pi * c.Radius
}

func main() {
	rect := Rectangle{Width: 5, Height: 10}
	circle := Circle{Radius: 7}
	fmt.Printf("Rectangle Area: %.2f\n", rect.Area())
	fmt.Printf("Rectangle Perimeter: %.2f\n", rect.Perimeter())

	fmt.Printf("Circle Area: %.2f\n", circle.Area())
	fmt.Printf("Circle Perimeter: %.2f\n", circle.Perimeter())

	var shape Shape
	shape = rect
	fmt.Printf("Shape Area (Rectangle): %.2f\n", shape.Area())
	fmt.Printf("Shape Perimeter (Rectangle): %.2f\n", shape.Perimeter())

	shape = circle
	fmt.Printf("Shape Area (Circle): %.2f\n", shape.Area())
	fmt.Printf("Shape Perimeter (Circle): %.2f\n", shape.Perimeter())
}
