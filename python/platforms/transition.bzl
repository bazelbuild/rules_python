load("//python:defs.bzl", _py_binary = "py_binary", _py_test = "py_test")

def _transition_platform_impl(_, attr):
    return {"//command_line_option:platforms": str(attr.target_platform)}

_transition_platform = transition(
    implementation = _transition_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _transition_py_binary_impl(ctx):
    target = ctx.attr.target[0]
    output = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.symlink(
        is_executable = True,
        output = output,
        target_file = target[DefaultInfo].files_to_run.executable,
    )
    env = {}
    for k, v in ctx.attr.env.items():
        env[k] = ctx.expand_location(v)
    providers = [
        DefaultInfo(
            executable = output,
            files = target[DefaultInfo].files,
            runfiles = target[DefaultInfo].default_runfiles,
        ),
        target[PyInfo],
        target[PyRuntimeInfo],
        target[InstrumentedFilesInfo],
        target[OutputGroupInfo],
        testing.TestEnvironment(environment = env),
    ]
    return providers

def _transition_py_test_impl(ctx):
    target = ctx.attr.target[0]
    output = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.symlink(
        is_executable = True,
        output = output,
        target_file = target[DefaultInfo].files_to_run.executable,
    )
    env = {}
    for k, v in ctx.attr.env.items():
        env[k] = ctx.expand_location(v)
    providers = [
        DefaultInfo(
            executable = output,
            files = target[DefaultInfo].files,
            runfiles = target[DefaultInfo].default_runfiles,
        ),
        target[PyInfo],
        target[PyRuntimeInfo],
        target[InstrumentedFilesInfo],
        target[OutputGroupInfo],
        # TODO(f0rmiga): testing.TestEnvironment is deprecated in favour of RunEnvironmentInfo but
        # RunEnvironmentInfo is not exposed in Bazel < 5.3.
        # https://github.com/bazelbuild/bazel/commit/dbdfa07e92f99497be9c14265611ad2920161483
        testing.TestEnvironment(environment = env),
    ]
    return providers

_COMMON_ATTRS = {
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
    "env": attr.string_dict(
        mandatory = False,
    ),
    "target": attr.label(
        executable = True,
        cfg = _transition_platform,
        mandatory = True,
        providers = [PyInfo],
    ),
    "target_platform": attr.label(
        mandatory = True,
    ),
    # Required to Opt-in to the transitions feature.
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
}

_transition_py_binary = rule(
    _transition_py_binary_impl,
    attrs = _COMMON_ATTRS,
    executable = True,
)

_transition_py_test = rule(
    _transition_py_test_impl,
    attrs = _COMMON_ATTRS,
    test = True,
)

def _py_rule(rule, transition_rule, name, target_platform, **kwargs):
    args = kwargs.pop("args", None)
    if args:
        fail("The args attribute is not supported under the custom transition rules. Refer to https://github.com/bazelbuild/rules_python/pull/846 for more context.")

    data = kwargs.pop("data", None)
    env = kwargs.pop("env", None)

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

    rule(
        name = "_" + name,
        data = data,
        env = env,

        # Attributes common to all build rules.
        compatible_with = compatible_with,
        deprecation = deprecation,
        distribs = distribs,
        exec_compatible_with = exec_compatible_with,
        exec_properties = exec_properties,
        features = features,
        restricted_to = restricted_to,
        tags = ["manual"] + (tags if tags else []),
        target_compatible_with = target_compatible_with,
        testonly = testonly,
        toolchains = toolchains,
        visibility = ["//visibility:private"],
        **kwargs
    )

    return transition_rule(
        name = name,
        tools = data,
        env = env,
        target = ":_" + name,

        # Attributes common to all build rules.
        target_platform = target_platform,
        compatible_with = compatible_with,
        deprecation = deprecation,
        distribs = distribs,
        exec_compatible_with = exec_compatible_with,
        exec_properties = exec_properties,
        features = features,
        restricted_to = restricted_to,
        tags = tags,
        target_compatible_with = target_compatible_with,
        testonly = testonly,
        toolchains = toolchains,
        visibility = visibility,
    )

def py_binary(name, target_platform, **kwargs):
    return _py_rule(_py_binary, _transition_py_binary, name, target_platform, **kwargs)

def py_test(name, target_platform, **kwargs):
    return _py_rule(_py_test, _transition_py_test, name, target_platform, **kwargs)
