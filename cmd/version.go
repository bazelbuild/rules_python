/*
Copyright © 2021 Aspect Build Systems

Not licensed for re-use
*/
package cmd

import (
	"aspect.build/cli/bazel"
	"aspect.build/cli/buildinfo"
	"fmt"
	"github.com/spf13/cobra"
)

var gnuFormat bool
var versionCmd *cobra.Command

var _ = RegisterCommandVar(func() {
	// versionCmd represents the version command
	versionCmd = &cobra.Command{
		Use:   "version",
		Short: "Print the version of aspect CLI as well as tools it invokes",
		Long:  `Prints version info on colon-separated lines, just like bazel does`,
		Run: versionExec,
	}
})

var _ = RegisterCommandInit(func() {
	versionCmd.PersistentFlags().BoolVarP(&gnuFormat, "gnu_format", "", false, "format help following GNU convention")
	rootCmd.AddCommand(versionCmd)
})

func versionExec(cmd *cobra.Command, args []string) {
	var version string
	if !buildinfo.IsStamped() {
		version = "unknown [not built with --stamp]"
	} else {
		version := buildinfo.Release
		if buildinfo.GitStatus != "clean" {
			version += " (with local changes)"
		}
	}
	// Check if the --gnu_format flag is set, if that is the case,
	// the version is printed differently
	bazelCmd := []string{"version"}
	if gnuFormat {
		fmt.Printf("Aspect %s\n", version)
		// Propagate the flag
		bazelCmd = append(bazelCmd, "--gnu_format")
	} else {
		fmt.Printf("Aspect version: %s\n", version)
	}
	bazel.Spawn(bazelCmd)
}
