#!/bin/bash
set -euo pipefail

out=replace
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    out="${BUILD_WORKSPACE_DIRECTORY}/$out"
else
    cp -v "$out" "bazel_out"
    out="bazel_out"
fi
exec uv pip compile --output-file "$out" "$@"
