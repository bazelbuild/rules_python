#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

if (( $# < 2 )); then
  echo "Need a docker platform as an argument." >&2
  exit 1
fi

readonly DOCKER_PLATFORM="$1"
shift

DOCKERFILE="$(rlocation rules_python_pypi_install_example/update_helper/Dockerfile)"
CONTEXT_DIR="$(dirname "${DOCKERFILE}")"
CONTAINER_TAG="pip-lock-${DOCKER_PLATFORM}:${USER}"

# Build the container that has the bare minimum to run the various setup.py
# scripts from our dependencies.
docker build \
  --platform="${DOCKER_PLATFORM}" \
  --file="${DOCKERFILE}" \
  --tag="${CONTAINER_TAG}" \
  "${CONTEXT_DIR}"

MOUNT_POINT_BAZEL_OUT="$(stat -c %m "${BUILD_WORKSPACE_DIRECTORY}/bazel-out/")"
MOUNT_POINT_HOME="$(stat -c %m "${HOME}")"

MOUNT_POINT_ARGS=(--volume "${HOME}:${HOME}")
if [[ MOUNT_POINT_BAZEL_OUT != MOUNT_POINT_HOME ]]; then
  MOUNT_POINT_ARGS+=(--volume "${MOUNT_POINT_BAZEL_OUT}:${MOUNT_POINT_BAZEL_OUT}")
fi

# Run the actual update. The assumption here is that mounting the user's home
# directory is sufficient to allow the tool to run inside the container without
# any issues. I.e. the cache and the source tree are available in the
# container.
docker run \
  --rm \
  --tty \
  --env BUILD_WORKSPACE_DIRECTORY="${BUILD_WORKSPACE_DIRECTORY}" \
  --network="host" \
  --workdir "${PWD}" \
  "${MOUNT_POINT_ARGS[@]}" \
  "${CONTAINER_TAG}" \
  "$@"

# Fix permissions.
sudo chown -R "${USER}:${USER}" "${BUILD_WORKSPACE_DIRECTORY}/bazel-bin/" || :
