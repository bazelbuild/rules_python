#!/bin/bash
# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A script to manage internal pip dependencies

readonly ROOT="$(dirname "$0")"/..
readonly START="# START: maintained by //tools/update_pip_deps.sh"
readonly END="# END: maintained by //tools/update_pip_deps.sh"

_assert_exists() {
    if ! type $1 >/dev/null; then
        echo "Please install '$1' to use this script"
        exit 1
    fi
}

_assert_exists jq
_assert_exists sed
_assert_exists awk
_assert_exists python

pip_args=(
    install
    --quiet
    --dry-run
    --ignore-installed
    --report -
    -r "$ROOT/python/pip_install/tools/requirements.txt"
)
report=$(python -m pip "${pip_args[@]}")

echo "$report" |
    jq --indent 4 '
        [
          .install[] | {
              name: ("pypi__" + (.metadata.name | sub("[._-]+"; "_"))),
              url: .download_info.url,
              sha256: .download_info.archive_info.hashes.sha256
          }
        ] | sort_by(.name)
        | .[] | [.name,.url,.sha256]
        ' |
    sed \
        -e 's/\[/(/g' \
        -e 's/\]/),/g' \
        -e 's/^/    /g' \
        -e 's/"$/",/g' |
    python "$ROOT"/tools/update_file.py \
        --start="$START" \
        --end="$END" \
        "$ROOT"/python/pip_install/repositories.bzl \
        "$@"

echo "$report" |
    jq --indent 4 '[.install[]|"pypi__" + (.metadata.name | sub("[._-]+"; "_"))] | sort' |
    sed \
        -e 's/\[//g' \
        -e 's/\]//g' \
        -e 's/"$/",/g' |
    awk NF |
    python "$ROOT/tools/update_file.py" \
        --start="$START" \
        --end="$END" \
        "$ROOT"/MODULE.bazel \
        "$@"
