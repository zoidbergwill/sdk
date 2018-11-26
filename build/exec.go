package build

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

func create(path string) (io.WriteCloser, error) {
	return os.Create(path)
}

func printCommand(cmd string, args ...string) {
	fmt.Fprintln(os.Stderr, "+", cmd, strings.Join(args, " "))
}

func execIn(wd string, out io.Writer, cmd string, args ...string) error {
	printCommand(cmd, args...)
	c := exec.Command(cmd, args...)
	c.Env = os.Environ()
	c.Dir = wd
	c.Stderr = os.Stderr
	c.Stdout = out
	return c.Run()
}
