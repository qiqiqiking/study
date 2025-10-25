package main

func doubleSlice(p *[]int) {
	slice := *p
	for i := range slice {
		slice[i] *= 2
	}
}
