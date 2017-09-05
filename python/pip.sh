#!/bin/bash -e

# Copyright 2017 The Bazel Authors. All rights reserved.
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

# TODO(mattmoor): Rewrite this in Python.
NAME="$1"
REQUIREMENTS_TXT="$2"
REQUIREMENTS_BZL="$3"
REPOSITORY_DIR="$4"

# TODO(mattmoor): Switch to a version of PIP we download.
pip wheel -w "${REPOSITORY_DIR}" -r "${REQUIREMENTS_TXT}"

PACKAGES=$(find "${REPOSITORY_DIR}" -type f -name "*.whl")

# Extract the package name from the .whl filename.
function package_name() {
  local whl="$1"
  echo ${whl} | cut -d'-' -f 1
}

# Create the repository rule name from the name given to
# pip_import and the WHL file.
function repository_name() {
  local whl="$1"
  echo "${NAME}_$(package_name ${whl})"
}

# Create a repository rule for installing a single WHL file.
function install_whl() {
  local whl="$1"
  cat <<EOF
  whl_library(
    name = "$(repository_name ${whl})",
    whl = "@${NAME}//:${whl}",
    requirements = "@${NAME}//:requirements.bzl",
  )

EOF
}

# Synthesize requirements.bzl from the list of WHL packages
# determined from requirements.txt.
cat > "${REQUIREMENTS_BZL}" <<EOF
"""Install pip requirements.

Generated from ${REQUIREMENTS_TXT}
"""

load("@io_bazel_rules_python//python:whl.bzl", "whl_library")

def pip_install():
$(for p in ${PACKAGES}; do
  install_whl "$(basename ${p})"
done)

_packages = {
$(for p in ${PACKAGES}; do
  whl="$(basename ${p})"
  echo "\"$(package_name ${whl})\": \"@$(repository_name ${whl})//lib\","
done)
}

all_packages = _packages.values()

def packages(name):
  name = name.replace("-", "_")
  return _packages[name]

EOF
