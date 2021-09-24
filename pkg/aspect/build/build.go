/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package build

import (
	"context"
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspect/build/bep"
	"aspect.build/cli/pkg/aspecterrors"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

// Build represents the aspect build command.
type Build struct {
	ioutils.Streams
	bzl        bazel.Spawner
	besBackend bep.BESBackend
}

// New creates a Build command.
func New(
	streams ioutils.Streams,
	bzl bazel.Spawner,
	besBackend bep.BESBackend,
) *Build {
	return &Build{
		Streams:    streams,
		bzl:        bzl,
		besBackend: besBackend,
	}
}

// Run runs the aspect build command, calling `bazel build` with a local Build
// Event Protocol backend used by Aspect plugins to subscribe to build events.
func (b *Build) Run(_ *cobra.Command, args []string) error {
	// TODO: register the BEP subscribers here with:
	// besBackend.RegisterSubscriber(plugin.BEPEventsSubscriber())
	if err := b.besBackend.Setup(); err != nil {
		return fmt.Errorf("failed to run build command: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := b.besBackend.ServeWait(ctx); err != nil {
		return fmt.Errorf("failed to run build command: %w", err)
	}
	defer b.besBackend.GracefulStop()

	besBackendFlag := fmt.Sprintf("--bes_backend=grpc://%s", b.besBackend.Addr())
	cmd := append([]string{"build", besBackendFlag}, args...)
	if exitCode, err := b.bzl.Spawn(cmd); exitCode != 0 {
		err = &aspecterrors.ExitError{
			Err:      err, // err can be nil, so don't wrap it with the full context.
			ExitCode: exitCode,
		}
		return err
	}

	subscriberErrors := b.besBackend.Errors()
	if len(subscriberErrors) > 0 {
		for _, err := range subscriberErrors {
			fmt.Fprintf(b.Streams.Stderr, "Error: failed to run build command: %v\n", err)
		}
		return &aspecterrors.ExitError{ExitCode: 1}
	}

	return nil
}
