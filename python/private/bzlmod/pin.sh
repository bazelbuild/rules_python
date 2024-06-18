#!/usr/bin/env bash

set -euo pipefail

uv_path=$1
shift

$uv_path pip compile \
    "$@"
