/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package docs

import (
	"fmt"
	"os"
	"strings"

	"aspect.build/cli/pkg/ioutils"
	"github.com/pkg/browser"
	"github.com/spf13/cobra"
)

type Docs struct {
	ioutils.Streams
}

func New(streams ioutils.Streams) *Docs {
	return &Docs{
		Streams: streams,
	}
}

func (v *Docs) Run(_ *cobra.Command, args []string) error {
	// TODO: we should open the browser to the bazel version matching what is running
	dest := "https://docs.bazel.build"

	// Detect requests for docs on rules, which we host
	if len(args) == 1 {
		if strings.HasPrefix(args[0], "rules_") {
			dest = fmt.Sprintf("https://docs.aspect.dev/%s", args[0])
		} else {
			dest = fmt.Sprintf("https://docs.bazel.build/versions/main/%s.html", args[0])
		}
	}
	// TODO: a way to lookup whatever the user typed after "docs" using docs.aspect.dev search
	// as far as I can tell, Algolia doesn't provide a way to render results on a dedicated search page
	// so I can't find a way to hyperlink to a search result.
	if err := browser.OpenURL(dest); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to open link in the browser: %v\n", err)
	}

	return nil
}
