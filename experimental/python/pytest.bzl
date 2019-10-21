# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Rules for converting py.test tests into bazel targets."""

load("//python:defs.bzl", "py_test")

def _sanitize_name(filename):
    return filename.replace("/", "__").replace(".", "_")

def _pytest_runner_impl(ctx):
    """Creates a wrapper script that runs py.test runner for given list of files."""
    runner_script = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.write(runner_script, """\
import sys
import pytest

# sys.exit to propagate the exit code to bazel
# sys.argv[1:] to pass additional flags from bazel --test_arg to py.test,
# e.g. "bazel test --test_arg=-s :my_test"
sys.exit(pytest.main(sys.argv[1:] + %s))
""" % repr(ctx.attr.test_files))
    return [DefaultInfo(executable = runner_script)]

pytest_runner = rule(
    implementation = _pytest_runner_impl,
    attrs = {
        "test_files": attr.string_list(mandatory = True, allow_empty = False),
    },
    doc = """Creates a wrapper script that runs py.test runner for given list of files.

    This is an implementation detail for pytest_test() macro. Use pytest_test() instead.
    """,
    executable = True,
)

def _make_pytest_target(name, test_files, **kwargs):
    """Instantiate pytest_runner rule and a corresponding py_test rule.

    Args:
        name: Name of the rule
        test_files: List of py.test files to be executed.
        **kwargs: Additional arguments to pass to the py_test targets, e.g. deps.
    """
    abs_test_files = [
        native.package_name() + "/" + test_file
        for test_file in test_files
    ]
    runner_file = name + "_runner.py"
    pytest_runner(
        name = runner_file,
        test_files = abs_test_files,
    )
    py_test(
        name = name,
        srcs = [runner_file] + test_files,
        main = runner_file,
        **kwargs
    )

def pytest_test(name, test_files, **kwargs):
    """Create bazel native py_test rules for tests using py.test framework.

    Args:
        - name: name of the generated test rule,
        - test_files: Python test files to run,
        - other arguments (e.g. "deps") are passed to py_test rule.

    Make sure that "deps" include:
     - py_library with pytest, e.g. created by pip_import.
     - py_library target that contains conftest.py file, if you use conftest.

    Example:
        py_library(
            name = "conftest",
            srcs = ["conftest.py"],
        )

        pytest_test(
            name = "all_test",
            test_files = glob(["*_test.py"]),
            deps = [
                ":conftest",
                requirement("pytest"),
            ],
        )
    """
    if len(test_files) > 1:
        for test_file in test_files:
            _make_pytest_target(
                name = name + "_" + _sanitize_name(test_file),
                test_files = [test_file],
                **kwargs
            )
    else:
        _make_pytest_target(name, test_files, **kwargs)
