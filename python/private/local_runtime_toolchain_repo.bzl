load("//python/private:py_toolchain_suite.bzl", "py_toolchain_suite")

_TOOLCHAIN_TEMPLATE = """
load("@rules_python//python/private:py_toolchain_suite.bzl", "py_toolchain_suite2")

py_toolchain_suite2(
    prefix = "{prefix}",
    user_repository_name = "{user_repository_name}",
    python_version = "",
    set_python_version_constraint = "False",
)
"""

def _local_runtime_toolchain_repo(rctx):
    rctx.file("WORKSPACE", "")
    rctx.file("MODULE.bazel", "")
    rctx.file("REPO.bazel", "")
    rctx.file("BUILD.bazel", _TOOLCHAIN_TEMPLATE.format(
        prefix = rctx.name,
        user_repository_name = rctx.attr.runtime_repo_name,
        target_compatible_with = rctx.attr.target_compatible_with,
        flag_values = {k: True for k in rctx.attr.target_settings},
        python_version = "",
        set_python_version_constraint = "False",
    ))

local_runtime_toolchain_repo = repository_rule(
    implementation = _local_runtime_toolchain_repo,
    attrs = {
        "runtime_repo_name": attr.string(),
        "target_compatible_with": attr.label_list(),
        "target_settings": attr.label_list(),
    },
)
