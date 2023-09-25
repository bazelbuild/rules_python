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

"""Public API for for building wheels."""

load("//python:py_binary.bzl", "py_binary")
load("//python/private:py_package.bzl", "py_package_lib")
load("//python/private:py_wheel.bzl", _PyWheelInfo = "PyWheelInfo", _py_wheel = "py_wheel")
load("//python/private:util.bzl", "copy_propagating_kwargs")

# Re-export as public API
PyWheelInfo = _PyWheelInfo

py_package = rule(
    implementation = py_package_lib.implementation,
    doc = """\
A rule to select all files in transitive dependencies of deps which
belong to given set of Python packages.

This rule is intended to be used as data dependency to py_wheel rule.
""",
    attrs = py_package_lib.attrs,
)

# Based on https://github.com/aspect-build/bazel-lib/tree/main/lib/private/copy_to_directory.bzl
# Avoiding a bazelbuild -> aspect-build dependency :(
def _py_wheel_dist_impl(ctx):
    dir = ctx.actions.declare_directory(ctx.attr.out)
    name_file = ctx.attr.wheel[PyWheelInfo].name_file
    cmds = [
        "mkdir -p \"%s\"" % dir.path,
        """cp "{}" "{}/$(cat "{}")" """.format(ctx.files.wheel[0].path, dir.path, name_file.path),
    ]
    ctx.actions.run_shell(
        inputs = ctx.files.wheel + [name_file],
        outputs = [dir],
        command = "\n".join(cmds),
        mnemonic = "CopyToDirectory",
        progress_message = "Copying files to directory",
        use_default_shell_env = True,
    )
    return [
        DefaultInfo(files = depset([dir]), runfiles = ctx.runfiles([dir])),
    ]

py_wheel_dist = rule(
    doc = """\
Prepare a dist/ folder, following Python's packaging standard practice.

See https://packaging.python.org/en/latest/tutorials/packaging-projects/#generating-distribution-archives
which recommends a dist/ folder containing the wheel file(s), source distributions, etc.

This also has the advantage that stamping information is included in the wheel's filename.
""",
    implementation = _py_wheel_dist_impl,
    attrs = {
        "out": attr.string(doc = "name of the resulting directory", mandatory = True),
        "wheel": attr.label(doc = "a [py_wheel rule](/docs/packaging.md#py_wheel_rule)", providers = [PyWheelInfo]),
    },
)

def py_wheel(name, twine = None, publish_args = [], **kwargs):
    """Builds a Python Wheel.

    Wheels are Python distribution format defined in https://www.python.org/dev/peps/pep-0427/.

    This macro packages a set of targets into a single wheel.
    It wraps the [py_wheel rule](#py_wheel_rule).

    Currently only pure-python wheels are supported.

    Examples:

    ```python
    # Package some specific py_library targets, without their dependencies
    py_wheel(
        name = "minimal_with_py_library",
        # Package data. We're building "example_minimal_library-0.0.1-py3-none-any.whl"
        distribution = "example_minimal_library",
        python_tag = "py3",
        version = "0.0.1",
        deps = [
            "//examples/wheel/lib:module_with_data",
            "//examples/wheel/lib:simple_module",
        ],
    )

    # Use py_package to collect all transitive dependencies of a target,
    # selecting just the files within a specific python package.
    py_package(
        name = "example_pkg",
        # Only include these Python packages.
        packages = ["examples.wheel"],
        deps = [":main"],
    )

    py_wheel(
        name = "minimal_with_py_package",
        # Package data. We're building "example_minimal_package-0.0.1-py3-none-any.whl"
        distribution = "example_minimal_package",
        python_tag = "py3",
        version = "0.0.1",
        deps = [":example_pkg"],
    )
    ```

    To publish the wheel to Pypi, the twine package is required.
    rules_python doesn't provide twine itself, see https://github.com/bazelbuild/rules_python/issues/1016
    However you can install it with pip_parse, just like we do in the WORKSPACE file in rules_python.

    Once you've installed twine, you can pass its label to the `twine` attribute of this macro,
    to get a "[name].publish" target.

    Example:

    ```python
    py_wheel(
        name = "my_wheel",
        twine = "@publish_deps_twine//:pkg",
        ...
    )
    ```

    Now you can run a command like the following, which publishes to https://test.pypi.org/

    ```sh
    % TWINE_USERNAME=__token__ TWINE_PASSWORD=pypi-*** \\
        bazel run --stamp --embed_label=1.2.4 -- \\
        //path/to:my_wheel.publish --repository testpypi
    ```

    Args:
        name:  A unique name for this target.
        twine: A label of the external location of the py_library target for twine
        publish_args: arguments passed to twine, e.g. ["--repository-url", "https://pypi.my.org/simple/"].
            These are subject to make var expansion, as with the `args` attribute.
            Note that you can also pass additional args to the bazel run command as in the example above.
        **kwargs: other named parameters passed to the underlying [py_wheel rule](#py_wheel_rule)
    """
    _dist_target = "{}.dist".format(name)
    py_wheel_dist(
        name = _dist_target,
        wheel = name,
        out = kwargs.pop("dist_folder", "{}_dist".format(name)),
        **copy_propagating_kwargs(kwargs)
    )

    _py_wheel(name = name, **kwargs)

    if twine:
        if not twine.endswith(":pkg"):
            fail("twine label should look like @my_twine_repo//:pkg")
        twine_main = twine.replace(":pkg", ":rules_python_wheel_entry_point_twine.py")
        twine_args = ["upload"]
        twine_args.extend(publish_args)
        twine_args.append("$(rootpath :{})/*".format(_dist_target))

        # TODO: use py_binary from //python:defs.bzl after our stardoc setup is less brittle
        # buildifier: disable=native-py
        py_binary(
            name = "{}.publish".format(name),
            srcs = [twine_main],
            args = twine_args,
            data = [_dist_target],
            imports = ["."],
            main = twine_main,
            deps = [twine],
            visibility = kwargs.get("visibility"),
            **copy_propagating_kwargs(kwargs)
        )

py_wheel_rule = _py_wheel
