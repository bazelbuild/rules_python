/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package ioutils

import (
	"io"
	"os"
)

type Streams struct {
	Stdin  io.Reader
	Stdout io.Writer
	Stderr io.Writer
}

var DefaultStreams = Streams{
	Stdin:  os.Stdin,
	Stdout: os.Stdout,
	Stderr: os.Stderr,
}
