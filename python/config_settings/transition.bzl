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

"""The transition module contains the rule definitions to wrap py_binary and py_test and transition
them to the desired target platform.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//python:defs.bzl", _py_binary = "py_binary", _py_test = "py_test")
load("//python/config_settings/private:py_args.bzl", "py_args")

def _transition_python_version_impl(_, attr):
    return {"//python/config_settings:python_version": str(attr.python_version)}

_transition_python_version = transition(
    implementation = _transition_python_version_impl,
    inputs = [],
    outputs = ["//python/config_settings:python_version"],
)

def _transition_py_impl(ctx):
    target = ctx.attr.target
    windows_constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    target_is_windows = ctx.target_platform_has_constraint(windows_constraint)
    executable = ctx.actions.declare_file(ctx.attr.name + (".exe" if target_is_windows else ""))
    ctx.actions.symlink(
        is_executable = True,
        output = executable,
        target_file = target[DefaultInfo].files_to_run.executable,
    )
    zipfile_symlink = None
    if target_is_windows:
        # Under Windows, the expected "<name>.zip" does not exist, so we have to
        # create the symlink ourselves to achieve the same behaviour as in macOS
        # and Linux.
        zipfile = None
        expected_target_path = target[DefaultInfo].files_to_run.executable.short_path[:-4] + ".zip"
        for file in target[DefaultInfo].default_runfiles.files.to_list():
            if file.short_path == expected_target_path:
                zipfile = file
        zipfile_symlink = ctx.actions.declare_file(ctx.attr.name + ".zip")
        ctx.actions.symlink(
            is_executable = True,
            output = zipfile_symlink,
            target_file = zipfile,
        )
    env = {}
    for k, v in ctx.attr.env.items():
        env[k] = ctx.expand_location(v)

    providers = [
        DefaultInfo(
            executable = executable,
            files = depset([zipfile_symlink] if zipfile_symlink else [], transitive = [target[DefaultInfo].files]),
            runfiles = ctx.runfiles([zipfile_symlink] if zipfile_symlink else []).merge(target[DefaultInfo].default_runfiles),
        ),
        target[PyInfo],
        target[PyRuntimeInfo],
        # Ensure that the binary we're wrapping is included in code coverage.
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["target"],
        ),
        target[OutputGroupInfo],
        # TODO(f0rmiga): testing.TestEnvironment is deprecated in favour of RunEnvironmentInfo but
        # RunEnvironmentInfo is not exposed in Bazel < 5.3.
        # https://github.com/bazelbuild/rules_python/issues/901
        # https://github.com/bazelbuild/bazel/commit/dbdfa07e92f99497be9c14265611ad2920161483
        testing.TestEnvironment(env),
    ]
    return providers

_COMMON_ATTRS = {
    "deps": attr.label_list(
        mandatory = False,
    ),
    "env": attr.string_dict(
        mandatory = False,
    ),
    "python_version": attr.string(
        mandatory = True,
    ),
    "srcs": attr.label_list(
        allow_files = True,
        mandatory = False,
    ),
    "target": attr.label(
        executable = True,
        cfg = "target",
        mandatory = True,
        providers = [PyInfo],
    ),
    # "tools" is a hack here. It should be "data" but "data" is not included by default in the
    # location expansion in the same way it is in the native Python rules. The difference on how
    # the Bazel deals with those special attributes differ on the LocationExpander, e.g.:
    # https://github.com/bazelbuild/bazel/blob/ce611646/src/main/java/com/google/devtools/build/lib/analysis/LocationExpander.java#L415-L429
    #
    # Since the default LocationExpander used by ctx.expand_location is not the same as the native
    # rules (it doesn't set "allowDataAttributeEntriesInLabel"), we use "tools" temporarily while a
    # proper fix in Bazel happens.
    #
    # A fix for this was proposed in https://github.com/bazelbuild/bazel/pull/16381.
    "tools": attr.label_list(
        allow_files = True,
        mandatory = False,
    ),
    # Required to Opt-in to the transitions feature.
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
    "_windows_constraint": attr.label(
        default = "@platforms//os:windows",
    ),
}

_transition_py_binary = rule(
    _transition_py_impl,
    attrs = _COMMON_ATTRS,
    cfg = _transition_python_version,
    executable = True,
)

_transition_py_test = rule(
    _transition_py_impl,
    attrs = _COMMON_ATTRS,
    cfg = _transition_python_version,
    test = True,
)

def _py_rule(rule_impl, transition_rule, name, python_version, **kwargs):
    pyargs = py_args(name, kwargs)
    args = pyargs["args"]
    data = pyargs["data"]
    env = pyargs["env"]
    srcs = pyargs["srcs"]
    deps = pyargs["deps"]
    main = pyargs["main"]

    # Attributes common to all build rules.
    # https://bazel.build/reference/be/common-definitions#common-attributes
    compatible_with = kwargs.pop("compatible_with", None)
    deprecation = kwargs.pop("deprecation", None)
    distribs = kwargs.pop("distribs", None)
    exec_compatible_with = kwargs.pop("exec_compatible_with", None)
    exec_properties = kwargs.pop("exec_properties", None)
    features = kwargs.pop("features", None)
    restricted_to = kwargs.pop("restricted_to", None)
    tags = kwargs.pop("tags", None)
    target_compatible_with = kwargs.pop("target_compatible_with", None)
    testonly = kwargs.pop("testonly", None)
    toolchains = kwargs.pop("toolchains", None)
    visibility = kwargs.pop("visibility", None)

    common_attrs = {
        "compatible_with": compatible_with,
        "deprecation": deprecation,
        "distribs": distribs,
        "exec_compatible_with": exec_compatible_with,
        "exec_properties": exec_properties,
        "features": features,
        "restricted_to": restricted_to,
        "target_compatible_with": target_compatible_with,
        "testonly": testonly,
        "toolchains": toolchains,
    }

    # Test-specific extra attributes.
    if "env_inherit" in kwargs:
        common_attrs["env_inherit"] = kwargs.pop("env_inherit")
    if "size" in kwargs:
        common_attrs["size"] = kwargs.pop("size")
    if "timeout" in kwargs:
        common_attrs["timeout"] = kwargs.pop("timeout")
    if "flaky" in kwargs:
        common_attrs["flaky"] = kwargs.pop("flaky")
    if "shard_count" in kwargs:
        common_attrs["shard_count"] = kwargs.pop("shard_count")
    if "local" in kwargs:
        common_attrs["local"] = kwargs.pop("local")

    # Binary-specific extra attributes.
    if "output_licenses" in kwargs:
        common_attrs["output_licenses"] = kwargs.pop("output_licenses")

    rule_impl(
        name = "_" + name,
        args = args,
        data = data,
        deps = deps,
        env = env,
        srcs = srcs,
        main = main,
        tags = ["manual"] + (tags if tags else []),
        visibility = ["//visibility:private"],
        **dicts.add(common_attrs, kwargs)
    )

    return transition_rule(
        name = name,
        args = args,
        deps = deps,
        env = env,
        python_version = python_version,
        srcs = srcs,
        tags = tags,
        target = ":_" + name,
        tools = data,
        visibility = visibility,
        **common_attrs
    )

def py_binary(name, python_version, **kwargs):
    return _py_rule(_py_binary, _transition_py_binary, name, python_version, **kwargs)

def py_test(name, python_version, **kwargs):
    return _py_rule(_py_test, _transition_py_test, name, python_version, **kwargs)
