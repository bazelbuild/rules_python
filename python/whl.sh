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
WHL="$1"
REQUIREMENTS="$2"
PKG=$(basename "${WHL}" | cut -d'-' -f 1)
DIST_INFO="$(basename "${WHL}" | cut -d'-' -f -2).dist-info"

unzip "${WHL}" > /dev/null

# Enumerate the names of dependencies from the WHL metadata.
function dependencies() {
    cat | python <<EOF
import json

# TODO(mattmoor): find a schema / specification to follow.
# Why are there so many layers?
with open("${DIST_INFO}/metadata.json", "r") as f:
  reqs = json.loads(f.read()).get("run_requires", [])
  for req in reqs:
    requires = req.get("requires", [])
    for entry in requires:
      (name, constraint) = entry.split(" ", 1)
      print name
EOF
}

DEPS=($(dependencies))

function name() {
    cat | python <<EOF
import json

with open("${DIST_INFO}/metadata.json", "r") as f:
  print json.loads(f.read())["name"]
EOF
}

# TODO(mattmoor): Consider exposing the metadata, e.g.
# cat > "name.bzl" <<EOF
# name = "$(name)"
# EOF


cat > "BUILD" <<EOF
package(default_visibility = ["//visibility:public"])

load("${REQUIREMENTS}", "packages")

py_library(
  name = "pkg",
  srcs = glob(["**/*.py"]),
  data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
  # This makes this directory a top-level in the python import
  # search path for anything that depends on this.
  imports = ["."],
  deps = [$(
  DELIM=
  for d in ${DEPS[@]}; do
    # Use the dictionary?
    echo -n "${DELIM}packages(\"${d}\")"
    DELIM=,
  done
  )],
)
EOF

# A convenience for terseness.
mkdir lib
cat > "lib/BUILD" <<EOF
package(default_visibility = ["//visibility:public"])

py_library(
  name = "lib",
  deps = ["//:pkg"],
)
EOF
