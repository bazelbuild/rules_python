def _impl(ctx):
    return

fake_executable = rule(
    implementation = _impl,
    executable = True,
)
