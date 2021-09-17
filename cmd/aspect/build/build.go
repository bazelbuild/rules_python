/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package build

import (
	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspect/build"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

// NewDefaultBuildCmd creates a new build cobra command with the default
// dependencies.
func NewDefaultBuildCmd() *cobra.Command {
	return NewBuildCmd(ioutils.DefaultStreams, bazel.New())
}

// NewBuildCmd creates a new build cobra command.
func NewBuildCmd(
	streams ioutils.Streams,
	bzl bazel.Spawner,
) *cobra.Command {
	b := build.New(streams, bzl)

	cmd := &cobra.Command{
		Use:   "build",
		Short: "Builds the specified targets, using the options.",
		Long: "Invokes bazel build on the specified targets. " +
			"See 'bazel help target-syntax' for details and examples on how to specify targets to build.",
		RunE: b.Run,
	}

	return cmd
}
