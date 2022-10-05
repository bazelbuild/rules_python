#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

version_py_binary=$("${VERSION_PY_BINARY}")

if [[ "${version_py_binary}" != "${VERSION_CHECK}" ]]; then
    echo >&2 "expected version '${VERSION_CHECK}' is different than returned '${version_py_binary}'"
    exit 1
fi
