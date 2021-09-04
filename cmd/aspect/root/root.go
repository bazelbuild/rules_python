/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package root

import (
	"os"

	"github.com/fatih/color"
	"github.com/mattn/go-isatty"
	"github.com/mitchellh/go-homedir"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"aspect.build/cli/cmd/aspect/version"
	"aspect.build/cli/docs/help/topics"
	"aspect.build/cli/pkg/ioutils"
)

var (
	boldCyan = color.New(color.FgCyan, color.Bold)
	faint = color.New(color.Faint)
)

func NewDefaultRootCmd() *cobra.Command {
	defaultInteractive := isatty.IsTerminal(os.Stdout.Fd()) || isatty.IsCygwinTerminal(os.Stdout.Fd())
	return NewRootCmd(ioutils.DefaultStreams, defaultInteractive)
}

func NewRootCmd(streams ioutils.Streams, defaultInteractive bool) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "aspect",
		Short: "Aspect.build bazel wrapper",
		Long:  boldCyan.Sprintf(`Aspect CLI`) + ` is a better frontend for running bazel`,
	}

	// ### Flags
	var cfgFile string
	var interactive bool
	cmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.aspect.yaml)")
	cmd.PersistentFlags().BoolVar(&interactive, "interactive", defaultInteractive, "Interactive mode (e.g. prompts for user input)")

	// ### Viper
	if cfgFile != "" {
		// Use config file from the flag.
		viper.SetConfigFile(cfgFile)
	} else {
		// Find home directory.
		home, err := homedir.Dir()
		cobra.CheckErr(err)

		// Search config in home directory with name ".aspect" (without extension).
		viper.AddConfigPath(home)
		viper.SetConfigName(".aspect")
	}
	viper.AutomaticEnv()
	if err := viper.ReadInConfig(); err == nil {
		faint.Fprintln(streams.Stderr, "Using config file:", viper.ConfigFileUsed())
	}

	// ### Child commands
	cmd.AddCommand(version.NewDefaultVersionCmd())

	// ### "Additional help topic commands" which are not runnable
	// https://pkg.go.dev/github.com/spf13/cobra#Command.IsAdditionalHelpTopicCommand
	cmd.AddCommand(&cobra.Command{
		Use:   "target-syntax",
		Short: "Documentation on Bazel's syntax for targets",
		Long:  topics.Read("target-syntax"),
	})

	return cmd
}
