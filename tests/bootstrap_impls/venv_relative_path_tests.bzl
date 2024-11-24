# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Unit tests for yaml.bzl"

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//python/private:py_executable_bazel.bzl", "relative_path")  # buildifier: disable=bzl-visibility

def _relative_path_test_impl(ctx):
    env = unittest.begin(ctx)

    # Basic test cases

    asserts.equals(
        env,
        "../../c/d",
        relative_path(
            from_ = "a/b",
            to = "c/d",
        ),
    )

    asserts.equals(
        env,
        "../../c/d",
        relative_path(
            from_ = "../a/b",
            to = "../c/d",
        ),
    )

    asserts.equals(
        env,
        "../../../c/d",
        relative_path(
            from_ = "../a/b",
            to = "../../c/d",
        ),
    )

    asserts.equals(
        env,
        "../../d",
        relative_path(
            from_ = "a/b/c",
            to = "a/d",
        ),
    )

    asserts.equals(
        env,
        "d/e",
        relative_path(
            from_ = "a/b/c",
            to = "a/b/c/d/e",
        ),
    )

    # Real examples

    # external py_binary uses external python runtime
    asserts.equals(
        env,
        "../../../../../rules_python~~python~python_3_9_x86_64-unknown-linux-gnu/bin/python3",
        relative_path(
            from_ = "../rules_python~/python/private/_py_console_script_gen_py.venv/bin",
            to = "../rules_python~~python~python_3_9_x86_64-unknown-linux-gnu/bin/python3",
        ),
    )

    # internal py_binary uses external python runtime
    asserts.equals(
        env,
        "../../../../rules_python~~python~python_3_9_x86_64-unknown-linux-gnu/bin/python3",
        relative_path(
            from_ = "test/version_default.venv/bin",
            to = "../rules_python~~python~python_3_9_x86_64-unknown-linux-gnu/bin/python3",
        ),
    )

    # external py_binary uses internal python runtime
    # asserts.equals(
    #    env,
    #    "???",
    #    relative_path(
    #        from_ = "../rules_python~/python/private/_py_console_script_gen_py.venv/bin",
    #        to = "python/python_3_9_x86_64-unknown-linux-gnu/bin/python3",
    #    ),
    #)
    # ^ TODO: Technically we can infer ".." to be the workspace name?

    # internal py_binary uses internal python runtime
    asserts.equals(
        env,
        "../../../python/python_3_9_x86_64-unknown-linux-gnu/bin/python3",
        relative_path(
            from_ = "scratch/main.venv/bin",
            to = "python/python_3_9_x86_64-unknown-linux-gnu/bin/python3",
        ),
    )

    return unittest.end(env)

relative_path_test = unittest.make(
    _relative_path_test_impl,
    attrs = {},
)

def relative_path_test_suite(name):
    unittest.suite(name, relative_path_test)
