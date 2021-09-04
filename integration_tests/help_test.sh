#!/usr/bin/env bash

set -o pipefail -o errexit -o nounset
HOME="$TEST_TMPDIR"
ASPECT="$TEST_SRCDIR/build_aspect_cli/cmd/aspect/aspect_/aspect"
export HOME
set -x

# Only capture stdout, just like `bazel help` prints to stdout
help=$($ASPECT help 2>/dev/null) || true

[[ "$help" =~ "Available Commands:" ]] || {
    echo >&2 "Expected 'aspect help' stdout to contain 'Available Commands:', but was"
    echo "$help"
    exit 1
}

# Should include additional help topics
help=$($ASPECT help target-syntax 2>/dev/null) || true
[[ "$help" =~ "Target pattern syntax" ]] || {
    echo >&2 "Expected 'aspect help target-syntax' stdout to contain 'Target pattern syntax' , but was"
    echo "$help"
    exit 1
}
