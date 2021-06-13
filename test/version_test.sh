#!/usr/bin/env bash

set -o pipefail -o errexit -o nounset

ASPECT="$TEST_SRCDIR/build_aspect_cli/cmd/aspect/aspect_/aspect"

# Only capture stdout, just like `bazel version` prints to stdout
ver=$($ASPECT version 2>/dev/null)

# Should print our own version
[[ "$ver" =~ "Aspect version:" ]] || {
    echo >&2 "Expected 'aspect version' stdout to contain 'Aspect version:', but was"
    echo "$ver"
    exit 1
}

# Should also call through to `bazel version`
[[ "$ver" =~ "Build label:" ]] || {
    echo >&2 "Expected 'aspect version' stdout to contain 'Build label:', but was"
    echo "$ver"
    exit 1
}
