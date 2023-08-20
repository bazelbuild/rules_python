#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

GENQUERY_OUTPUT="$(cat ./cognitojwt_deps)"
readonly GENQUERY_OUTPUT

EXPECTED_OUTPUT="$(cat <<EOF
@pypi//cffi:cffi
@pypi//cognitojwt:cognitojwt
@pypi//cryptography:cryptography
@pypi//ecdsa:ecdsa
@pypi//pyasn1:pyasn1
@pypi//pycparser:pycparser
@pypi//python-jose:python-jose
@pypi//rsa:rsa
@pypi//six:six
EOF
)"
readonly EXPECTED_OUTPUT

if [[ "${EXPECTED_OUTPUT}" != "${GENQUERY_OUTPUT}" ]]; then
    cat >&2 <<EOF
Expected:
${EXPECTED_OUTPUT}
But got:
${GENQUERY_OUTPUT}
EOF
    exit 1
fi
