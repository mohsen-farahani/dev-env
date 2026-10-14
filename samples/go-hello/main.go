package main

import "fmt"

func Sum(nums []int) int {
	total := 0
	for _, n := range nums {
		total += n // breakpoint target
	}
	return total
}

func main() {
	fmt.Println("sum =", Sum([]int{1, 2, 3, 4}))
}
