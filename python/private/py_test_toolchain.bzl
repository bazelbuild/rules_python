"""
Simple toolchain which overrides env and exec requirements.
"""

PytestProvider = provider(
    fields = [
        "coverage_rc",
    ],
)

def _py_test_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            py_test_info = PytestProvider(
                coverage_rc = ctx.attr.coverage_rc,
            ),
        ),
    ]

py_test_toolchain = rule(
    implementation = _py_test_toolchain_impl,
    attrs = {
        "coverage_rc": attr.label(
            allow_single_file = True,
        ),
    },
)
