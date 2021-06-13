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

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version of aspect CLI as well as tools it invokes",
	Long:  `Prints version info on colon-separated lines, just like bazel does`,
	Run: func(cmd *cobra.Command, args []string) {
		if !buildinfo.IsStamped() {
			fmt.Println("Aspect was not built with --stamp")
		} else {
			version := buildinfo.Release
			if buildinfo.GitStatus != "clean" {
				version += " (in a dirty clone)"
			}
			fmt.Printf("Aspect version: %s\n", version)
		}
		bazel.Spawn("version")
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
