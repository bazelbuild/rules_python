set -o errexit -o nounset -o pipefail

"$1" bar

RESULT=$(< foo_result)
if [ "$RESULT" != "bar has come and gone" ]
then
    cat <<EOF >&2
Unexpected result of Python run: $RESULT
                       expected: bar has come and gone
EOF
    exit 1
fi
