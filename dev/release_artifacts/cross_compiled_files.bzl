"""Rule to build a target for several platforms in one build."""

def _platforms_transition_impl(_settings, attr):
    # A split transition: one configuration per platform, keyed by its label.
    return {
        str(platform): {"//command_line_option:platforms": str(platform)}
        for platform in attr.platforms
    }

_platforms_transition = transition(
    implementation = _platforms_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _cross_compiled_files_impl(ctx):
    # Without platforms, the transition leaves src in this target's
    # configuration, so skip it.
    if not ctx.attr.platforms:
        return [DefaultInfo()]

    # With a transition, ctx.attr.src is a list: one target per platform.
    files = [src[DefaultInfo].files for src in ctx.attr.src]
    return [DefaultInfo(files = depset(transitive = files))]

cross_compiled_files = rule(
    implementation = _cross_compiled_files_impl,
    doc = """
Builds `src` for each platform in `platforms`, in one build.

`--platforms` selects one target platform for the whole build; this builds
`src` for every platform in `platforms` instead. With no platforms, it builds
nothing.
""",
    attrs = {
        "platforms": attr.label_list(
            doc = "The platforms to build `src` for.",
            providers = [platform_common.PlatformInfo],
        ),
        "src": attr.label(
            cfg = _platforms_transition,
            doc = "The target to build.",
            mandatory = True,
        ),
    },
)
