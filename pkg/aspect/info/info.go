/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package info

import (
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
	"github.com/spf13/cobra"
)

type Info struct {
	ioutils.Streams

	ShowMakeEnv bool
}

func New(streams ioutils.Streams) *Info {
	return &Info{
		Streams: streams,
	}
}

func (v *Info) Run(_ *cobra.Command, args []string) error {
	bazelCmd := []string{"info"}
	if v.ShowMakeEnv {
		// Propagate the flag
		bazelCmd = append(bazelCmd, "--show_make_env")
	}
	bazelCmd = append(bazelCmd, args...)
	bzl := bazel.New()
	bzl.Spawn(bazelCmd)

	return nil
}
