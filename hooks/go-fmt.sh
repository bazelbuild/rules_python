#!/usr/bin/env bash
set -e

output="$(bazel 2>/dev/null run -- @go_sdk//:bin/gofmt -l "$@")"

[[ -z "$output" ]] && exit 0

echo >&2 "Go files must be formatted with gofmt. Please run:"
for f in $output; do
  echo >&2 "  bazel run -- @go_sdk//:bin/gofmt -w $PWD/$f"
done

exit 1
