#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

export DOCKER_BUILDKIT=1

set -x
for py in py310 py311; do
  bazel run \
    --config="${py}" \
    --run_under="//update_helper linux/amd64" \
    --platforms=//platforms:linux_x86_64 \
    //:requirements.update
  bazel run \
    --config="${py}" \
    --run_under="//update_helper linux/arm64/v8" \
    --platforms=//platforms:linux_aarch64 \
    //:requirements.update
done
