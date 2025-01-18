local M = {}

M.main = [[
package main

import (
	"fmt"
)

func main() {
	fmt.Println("Hello, playground")
}
]]

M.test = [[
package xxx_test

import (
	"testing"
)

func TestXXX(t *testing.T) {
	if false {
		t.Errorf("Expected true, got false")
	}
}
]]

return M
