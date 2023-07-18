#!/bin/bash
#
# A script to manage internal dependencies

pip_args=(
    install
    --quiet
    --dry-run
    --ignore-installed
    --report -
    -r "$(dirname "$0")"/../python/pip_install/tools/requirements.txt
)
echo "Copy the following to //python/pip_install/requirements.bzl"
echo "    # Generated with //tools:$(basename $0)"
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
        -e 's/"$/",/g'

echo ""
echo "====================================="
echo "  Copy the following to MODULE.bazel"
echo "====================================="
echo "    # Generated with //tools:$(basename $0)"
echo "$report" |
    jq --indent 4 '[.install[]|"pypi__" + (.metadata.name | sub("[._-]+"; "_"))] | sort' |
    sed \
        -e 's/\[//g' \
        -e 's/\]//g' \
        -e 's/"$/",/g' |
    awk NF
