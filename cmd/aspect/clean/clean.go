/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package clean

import (
	"github.com/spf13/cobra"

	"aspect.build/cli/pkg/aspect/clean"
	"aspect.build/cli/pkg/bazel"
	"aspect.build/cli/pkg/ioutils"
)

// NewDefaultCleanCmd creates a new clean cobra command with the default
// dependencies.
func NewDefaultCleanCmd() *cobra.Command {
	return NewCleanCmd(ioutils.DefaultStreams, bazel.New())
}

// NewCleanCmd creates a new clean cobra command.
func NewCleanCmd(
	streams ioutils.Streams,
	bzl bazel.Spawner,
) *cobra.Command {
	b := clean.New(streams, bzl)

	cmd := &cobra.Command{
		Use:   "clean",
		Short: "Removes the output tree",
		Long: `Removes bazel-created output, including all object files, and bazel metadata.

clean deletes the output directories for all build configurations performed by
this Bazel instance, or the entire working tree created by this Bazel instance,
and resets internal caches.

If executed without any command-line options, then the output directory for all
configurations will be cleaned.

Recall that each Bazel instance is associated with a single workspace,
thus the clean command will delete all outputs from all builds you've
done with that Bazel instance in that workspace.

NOTE: clean is primarily intended for reclaiming disk space for workspaces
that are no longer needed.
It causes all subsequent builds to be non-incremental.
If this is not your intent, consider these alternatives:

Do a one-off non-incremental build:
	bazel --output_base=$(mktemp -d) ...

Force repository rules to re-execute:
	bazel sync --configure

Workaround inconistent state:
	Bazel's incremental rebuilds are designed to be correct, so clean
	should never be required due to inconsistencies in the build.
	Such problems are fixable and these bugs are a high priority.
	If you ever find an incorrect incremental build, please file a bug report,
	and only use clean as a temporary workaround.`,
		RunE: b.Run,
	}

	cmd.PersistentFlags().BoolVarP(&b.Expunge, "expunge", "", false, `Remove the entire output_base tree.
This removes all build output, external repositories,
and temp files created by Bazel.
It also stops the Bazel server after the clean,
equivalent to the shutdown command.`)

	cmd.PersistentFlags().BoolVarP(&b.ExpungeAsync, "expunge_async", "", false, `Expunge in the background.
It is safe to invoke a Bazel command in the same
workspace while the asynchronous expunge continues to run.
Note, however, that this may introduce IO contention.`)
	return cmd
}
