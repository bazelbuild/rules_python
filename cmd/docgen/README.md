# Generating docs

Run `bazel run //cmd/docgen /tmp | less`

Note that piping the command to less is required, so that it's not interactive.
Otherwise we'll turn on coloring and put ANSI escape codes in our markdown.

The github.com/aspect-dev/docs repo will do the work of publishing the outputs of this docgen step.
