/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package aspecterrors

// ExitError encapsulates an upstream error and an exit code. It is used by the
// aspect CLI main entrypoint to propagate meaningful exit error codes as the
// aspect CLI exit code.
type ExitError struct {
	Err      error
	ExitCode int
}

// Error returns the call to the encapsulated error.Error().
func (err *ExitError) Error() string {
	if err.Err != nil {
		return err.Err.Error()
	}
	return ""
}
