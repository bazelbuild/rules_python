/*
Copyright © 2021 Aspect Build Systems

Not licensed for re-use
*/

package docs

import (
	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspect/docs"
	"aspect.build/cli/pkg/ioutils"
)

func NewDefaultDocsCmd() *cobra.Command {
	return NewDocsCmd(ioutils.DefaultStreams)
}

func NewDocsCmd(streams ioutils.Streams) *cobra.Command {
	v := docs.New(streams)

	cmd := &cobra.Command{
		Use:   "docs",
		Short: "Open documentation in the browser",
		Long: `Given a selected topic, open the relevant API docs in a browser window.
The mechanism of choosing the browser to open is documented at https://github.com/pkg/browser
By default, opens docs.bazel.build`,
		RunE: v.Run,
	}

	return cmd
}
