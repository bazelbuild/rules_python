/*
Copyright © 2021 Aspect Build Systems

Not licensed for re-use
*/

package test

import (
	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspect/test"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

func NewDefaultTestCmd() *cobra.Command {
	return NewTestCmd(ioutils.DefaultStreams, bazel.New())
}

func NewTestCmd(streams ioutils.Streams, bzl bazel.Spawner) *cobra.Command {
	v := test.New(streams, bzl)

	cmd := &cobra.Command{
		Use:   "test",
		Short: "Builds the specified targets and runs all test targets among them.",
		Long: `Builds the specified targets and runs all test targets among them (test targets
might also need to satisfy provided tag, size or language filters) using
the specified options.

This command accepts all valid options to 'build', and inherits
defaults for 'build' from your .bazelrc.  If you don't use .bazelrc,
don't forget to pass all your 'build' options to 'test' too.

See 'bazel help target-syntax' for details and examples on how to
specify targets.
`,
		RunE: v.Run,
	}

	return cmd
}
