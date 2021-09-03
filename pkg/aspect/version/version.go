/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package version

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

type Version struct {
	ioutils.Streams

	BuildinfoRelease   string
	BuildinfoGitStatus string
	GNUFormat          bool
}

func New(streams ioutils.Streams) *Version {
	return &Version{
		Streams: streams,
	}
}

func (v *Version) Run(_ *cobra.Command, _ []string) error {
	var versionBuilder strings.Builder
	if v.BuildinfoRelease != "" {
		versionBuilder.WriteString(v.BuildinfoRelease)
		if v.BuildinfoGitStatus != "clean" {
			versionBuilder.WriteString(" (with local changes)")
		}
	} else {
		versionBuilder.WriteString("unknown [not built with --stamp]")
	}
	version := versionBuilder.String()
	// Check if the --gnu_format flag is set, if that is the case,
	// the version is printed differently
	bazelCmd := []string{"version"}
	if v.GNUFormat {
		fmt.Fprintf(v.Stdout, "Aspect %s\n", version)
		// Propagate the flag
		bazelCmd = append(bazelCmd, "--gnu_format")
	} else {
		fmt.Fprintf(v.Stdout, "Aspect version: %s\n", version)
	}
	bzl := bazel.New()
	bzl.Spawn(bazelCmd)

	return nil
}
