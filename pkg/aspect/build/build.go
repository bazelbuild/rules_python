/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package build

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/spf13/cobra"
	buildv1 "google.golang.org/genproto/googleapis/devtools/build/v1"

	"aspect.build/cli/pkg/aspect/build/bep"
	"aspect.build/cli/pkg/aspecterrors"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/hooks"
	"aspect.build/cli/pkg/ioutils"
)

// Build represents the aspect build command.
type Build struct {
	ioutils.Streams
	bzl        bazel.Spawner
	besBackend bep.BESBackend
	hooks      *hooks.Hooks
}

// New creates a Build command.
func New(
	streams ioutils.Streams,
	bzl bazel.Spawner,
	besBackend bep.BESBackend,
	hooks *hooks.Hooks,
) *Build {
	return &Build{
		Streams:    streams,
		bzl:        bzl,
		besBackend: besBackend,
		hooks:      hooks,
	}
}

// Run runs the aspect build command, calling `bazel build` with a local Build
// Event Protocol backend used by Aspect plugins to subscribe to build events.
func (b *Build) Run(ctx context.Context, cmd *cobra.Command, args []string) (exitErr error) {
	// TODO(f0rmiga): this is a hook for the build command and should be discussed
	// as part of the plugin design.
	defer func() {
		errs := b.hooks.ExecutePostBuild().Errors()
		if len(errs) > 0 {
			for _, err := range errs {
				fmt.Fprintf(b.Streams.Stderr, "Error: failed to run build command: %v\n", err)
			}
			var err *aspecterrors.ExitError
			if errors.As(exitErr, &err) {
				err.ExitCode = 1
			}
		}
	}()

	if err := b.besBackend.Setup(); err != nil {
		return fmt.Errorf("failed to run build command: %w", err)
	}
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	if err := b.besBackend.ServeWait(ctx); err != nil {
		return fmt.Errorf("failed to run build command: %w", err)
	}
	defer b.besBackend.GracefulStop()

	besBackendFlag := fmt.Sprintf("--bes_backend=grpc://%s", b.besBackend.Addr())
	exitCode, bazelErr := b.bzl.Spawn(append([]string{"build", besBackendFlag}, args...))

	// Process the subscribers errors before the Bazel one.
	subscriberErrors := b.besBackend.Errors()
	if len(subscriberErrors) > 0 {
		for _, err := range subscriberErrors {
			fmt.Fprintf(b.Streams.Stderr, "Error: failed to run build command: %v\n", err)
		}
		exitCode = 1
	}

	if exitCode != 0 {
		err := &aspecterrors.ExitError{ExitCode: exitCode}
		if bazelErr != nil {
			err.Err = bazelErr
		}
		return err
	}

	return nil
}

// Plugin defines only the methods for the build command.
type Plugin interface {
	// BEPEventsSubscriber is used to verify whether an Aspect plugin registers
	// itself to receive the Build Event Protocol events.
	BEPEventCallback(event *buildv1.BuildEvent) error
	// TODO(f0rmiga): test the build hooks after implementing the plugin system.
	PostBuildHook() error
}
