/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package build

import (
	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspecterrors"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

// Build represents the aspect build command.
type Build struct {
	ioutils.Streams
	bzl bazel.Spawner
}

// New creates a Build command.
func New(
	streams ioutils.Streams,
	bzl bazel.Spawner,
) *Build {
	return &Build{
		Streams: streams,
		bzl:     bzl,
	}
}

// Run runs the aspect build command.
func (b *Build) Run(_ *cobra.Command, args []string) error {
	cmd := append([]string{"build"}, args...)
	if exitCode, err := b.bzl.Spawn(cmd); exitCode != 0 {
		err = &aspecterrors.ExitError{
			Err:      err,
			ExitCode: exitCode,
		}
		return err
	}

	return nil
}
