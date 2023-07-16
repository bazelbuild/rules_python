#!/bin/bash
#
# A script to manage internal dependencies

internal_deps=(
    build==0.9
    click==8.0.1
    colorama
    importlib_metadata==1.4.0
    installer
    more_itertools==8.13.0
    packaging==22.0
    pep517
    pip==22.3.1
    pip_tools==6.12.1
    setuptools==60.10
    tomli
    wheel==0.38.4
    zipp==1.0.0
)
echo "Copy the following to //python/pip_install/requirements.bzl"
echo "    # Generated with //tools:$(basename $0)"
report=$(python -m pip install --quiet --dry-run --ignore-installed --report - ${internal_deps[@]})

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
