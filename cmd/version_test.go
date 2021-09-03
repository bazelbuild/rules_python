package cmd

import (
	"bytes"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

var (
	// Stdout points to the output buffer to send screen output
	Stdout io.Writer = os.Stdout
	// Stderr points to the output buffer to send errors to the screen
	Stderr io.Writer = os.Stderr
)

// Returns a buffer for stdout, stderr, and a function.
// The function should be used as a defer to restore the state
func testSetupCli(args string) (*bytes.Buffer, *bytes.Buffer, func()) {
	// Save
	oldargs := os.Args
	oldStdout := Stdout
	oldStderr := Stderr

	// Create new buffers
	stdout := new(bytes.Buffer)
	stderr := new(bytes.Buffer)

	// Set buffers
	Stdout = stdout
	Stderr = stderr
	os.Args = strings.Split(args, " ")

	return stdout, stderr, func() {
		os.Args = oldargs
		Stdout = oldStdout
		Stderr = oldStderr
	}
}

// Execute cli and return the buffers of standard out, standard error,
// and error.
// Callers must managage global variables using Patch from pkg/tests
func executeCliRaw(cli string) (*bytes.Buffer, *bytes.Buffer, error) {
	so, se, r := testSetupCli(cli)

	// Defer to cleanup state
	defer r()

	// Start the CLI
	err := Main()

	return so, se, err
}

func executeCli(cli string) ([]string, []string, error) {
	so, se, err := executeCliRaw(cli)

	return strings.Split(so.String(), "\n"),
		strings.Split(se.String(), "\n"),
		err
}

func TestVersion(t *testing.T) {
    input := "aspect version"
    _, stderr, err := executeCli(input)
    assert.NoError(t, err)
    assert.Contains(t, stderr, "version")
}

func TestVersionGnuFormat(t *testing.T) {
    t.Skip()
    input := "aspect version --gnu-format"
    lines, _, err := executeCli(input)
    assert.NoError(t, err)
    assert.Contains(t, lines, "version")
}
