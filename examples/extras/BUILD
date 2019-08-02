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
package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("@examples_extras//:requirements.bzl", "requirement")
load("//python:defs.bzl", "py_test")

py_test(
    name = "extras_test",
    srcs = ["extras_test.py"],
    deps = [
        requirement("google-cloud-language"),
        # Make sure that we can resolve the "extra" dependency
        requirement("googleapis-common-protos[grpc]"),
    ],
    python_version = "PY2",
)
