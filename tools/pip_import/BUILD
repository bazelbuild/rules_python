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

load("@piptool_deps//:requirements.bzl", "requirement")
load("//tools:subpar.bzl", "par_binary")

par_binary(
    name = "pip_import",
    srcs = [
        "codegen.py",
        "distribution.py",
        "main.py",
        "metadata.py",
        "package.py",
        "pip_import.py",
        "pypi.py",
    ],
    main = "main.py",
    deps = [
        "//tools/utils",
        requirement("setuptools"),
        requirement("toml"),
        requirement("pkginfo"),
        requirement("requests"),
        requirement("packaging"),
        requirement("configparser"),
        requirement("cachecontrol[filecache]"),
    ],
)

filegroup(
    name = "distribution",
    srcs = [
        "BUILD",
    ],
    visibility = ["//:__pkg__"],
)
