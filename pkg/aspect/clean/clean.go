/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package clean

import (
	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspecterrors"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

// Clean represents the aspect clean command.
type Clean struct {
	ioutils.Streams
	bzl bazel.Spawner

	Expunge      bool
	ExpungeAsync bool
}

// New creates a Clean command.
func New(
	streams ioutils.Streams,
	bzl bazel.Spawner,
) *Clean {
	return &Clean{
		Streams: streams,
		bzl:     bzl,
	}
}

// Run runs the aspect build command.
func (c *Clean) Run(_ *cobra.Command, _ []string) error {
	// TODO(alex): when interactive, prompt the user:
	// First time running aspect clean?
	// Then ask, why do you want to clean?
	// - reclaim disk space?
	// - workaround inconsistent state
	// - experiment with a one-off non-incremental build
	// then ask
	// do you want to see this wizard again next time?
	// and if not, record in the cache file to inhibit next time
	cmd := []string{"clean"}
	if c.Expunge {
		cmd = append(cmd, "--expunge")
	}
	if c.ExpungeAsync {
		cmd = append(cmd, "--expunge_async")
	}
	if exitCode, err := c.bzl.Spawn(cmd); exitCode != 0 {
		err = &aspecterrors.ExitError{
			Err:      err,
			ExitCode: exitCode,
		}
		return err
	}

	return nil
}
