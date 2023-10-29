#!/bin/bash


declare -a extra_env
while IFS='=' read -r -d '' name value; do
  if [[ "$name" == READTHEDOCS* ]]; then
    extra_env+=("--//sphinxdocs:extra_env=$name=$value")
  fi
done < <(env -0)

set -x
bazel run \
  "--//sphinxdocs:extra_defines=version=$READTHEDOCS_VERSION" \
  "${extra_env[@]}" \
  //docs/sphinx:readthedocs_install
