#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")"/../../examples/bzlmod
bazel mod deps
