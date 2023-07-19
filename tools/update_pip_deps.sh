#!/bin/bash
#
# A script to manage internal dependencies

readonly ROOT="$(dirname "$0")"/..
readonly START="# START: maintained by //tools/update_pip_deps.sh"
readonly END="# END: maintained by //tools/update_pip_deps.sh"

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
