"""Fake for providing CcToolchainConfigInfo."""

def _impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = ctx.attr.toolchain_identifier,
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = ctx.attr.target_cpu,
        target_libc = "unknown",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
    )

fake_cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "target_cpu": attr.string(),
        "toolchain_identifier": attr.string(),
    },
    provides = [CcToolchainConfigInfo],
)
