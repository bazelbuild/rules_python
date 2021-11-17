#!/bin/bash

set -o errexit -o nounset -o pipefail

echo '#!/bin/bash'
echo 'set -o errexit -o nounset -o pipefail'
# shellcheck disable=SC2016
echo 'dst=$1'
# shellcheck disable=SC2016
echo 'mkdir -p "${dst}"'

for artifact in "$@"; do
  echo "echo \"Copying ${artifact} to \${dst}\""
  echo "cp \"${artifact}\" \"\${dst}\""
done
