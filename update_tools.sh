#!/bin/bash

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

set -euo pipefail

usage() {
  echo "Usage: $0 [--nodocker]" 1>&2
  exit 1
}

if [ "$#" -eq 0 ] ; then
  docker build --no-cache -f tools/update_tools/Dockerfile --tag rules_python:update_tools .
  docker run -v"$PWD":/opt/rules_python_source rules_python:update_tools
elif [ "$#" -eq 1 -a "$1" == "--nodocker" ] ; then
  bazel build //packaging:piptool.par //packaging:whltool.par
  cp bazel-bin/packaging/piptool.par tools/piptool.par
  cp bazel-bin/packaging/whltool.par tools/whltool.par
else
  usage
fi
