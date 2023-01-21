#!/usr/bin/env bash
# Manual test, run outside of Bazel, to check that our runfiles wheel should be functional
# for users who install it from pypi.
set -o errexit 

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

bazel 2>/dev/null build --stamp --embed_label=1.2.3 //python/runfiles:wheel
wheelpath=$SCRIPTPATH/../../$(bazel 2>/dev/null cquery --output=files //python/runfiles:wheel)
PYTHONPATH=$wheelpath python3 -c 'import importlib;print(importlib.import_module("runfiles"))'
