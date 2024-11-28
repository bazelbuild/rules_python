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
load("//python:py_binary.bzl", _py_binary = "py_binary")
load("//python:py_info.bzl", "PyInfo")
load("//python:py_runtime_info.bzl", "PyRuntimeInfo")
load("//python:py_test.bzl", _py_test = "py_test")
load("//python/config_settings/private:py_args.bzl", "py_args")
load("//python/private:reexports.bzl", "BuiltinPyInfo", "BuiltinPyRuntimeInfo")

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
    default_outputs = []
    if target_is_windows:
        # NOTE: Bazel 6 + host=linux + target=windows results in the .exe extension missing
        inner_bootstrap_path = _strip_suffix(target[DefaultInfo].files_to_run.executable.short_path, ".exe")
        inner_bootstrap = None
        inner_zip_file_path = inner_bootstrap_path + ".zip"
        inner_zip_file = None
        for file in target[DefaultInfo].files.to_list():
            if file.short_path == inner_bootstrap_path:
                inner_bootstrap = file
            elif file.short_path == inner_zip_file_path:
                inner_zip_file = file

        # TODO: Use `fragments.py.build_python_zip` once Bazel 6 support is dropped.
        # Which file the Windows .exe looks for depends on the --build_python_zip file.
        # Bazel 7+ has APIs to know the effective value of that flag, but not Bazel 6.
        # To work around this, we treat the existence of a .zip in the default outputs
        # to mean --build_python_zip=true.
        if inner_zip_file:
            suffix = ".zip"
            underlying_launched_file = inner_zip_file
        else:
            suffix = ""
            underlying_launched_file = inner_bootstrap

        if underlying_launched_file:
            launched_file_symlink = ctx.actions.declare_file(ctx.attr.name + suffix)
            ctx.actions.symlink(
                is_executable = True,
                output = launched_file_symlink,
                target_file = underlying_launched_file,
            )
            default_outputs.append(launched_file_symlink)

    env = {}
    for k, v in ctx.attr.env.items():
        env[k] = ctx.expand_location(v)

    providers = [
        DefaultInfo(
            executable = executable,
            files = depset(default_outputs, transitive = [target[DefaultInfo].files]),
            runfiles = ctx.runfiles(default_outputs).merge(target[DefaultInfo].default_runfiles),
        ),
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
    if PyInfo in target:
        providers.append(target[PyInfo])
    if BuiltinPyInfo != None and BuiltinPyInfo in target and PyInfo != BuiltinPyInfo:
        providers.append(target[BuiltinPyInfo])

    if PyRuntimeInfo in target:
        providers.append(target[PyRuntimeInfo])
    if BuiltinPyRuntimeInfo != None and BuiltinPyRuntimeInfo in target and PyRuntimeInfo != BuiltinPyRuntimeInfo:
        providers.append(target[BuiltinPyRuntimeInfo])
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

_PY_TEST_ATTRS = {
    # Magic attribute to help C++ coverage work. There's no
    # docs about this; see TestActionBuilder.java
    "_collect_cc_coverage": attr.label(
        default = "@bazel_tools//tools/test:collect_cc_coverage",
        executable = True,
        cfg = "exec",
    ),
    # Magic attribute to make coverage work. There's no
    # docs about this; see TestActionBuilder.java
    "_lcov_merger": attr.label(
        default = configuration_field(fragment = "coverage", name = "output_generator"),
        executable = True,
        cfg = "exec",
    ),
}

_transition_py_binary = rule(
    _transition_py_impl,
    attrs = _COMMON_ATTRS | _PY_TEST_ATTRS,
    cfg = _transition_python_version,
    executable = True,
    fragments = ["py"],
)

_transition_py_test = rule(
    _transition_py_impl,
    attrs = _COMMON_ATTRS | _PY_TEST_ATTRS,
    cfg = _transition_python_version,
    test = True,
    fragments = ["py"],
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

def _strip_suffix(s, suffix):
    if s.endswith(suffix):
        return s[:-len(suffix)]
    else:
        return s
