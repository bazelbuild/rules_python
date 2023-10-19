def _find_patch_executable_impl(ctx):
    patch_binary = None
    for file in ctx.attr.src.files.to_list():
        if not file.is_directory:
            if patch_binary:
                fail("Found 2 candidates for patch binary. %s and %s" %
                     (patch_binary.path, file.path))
            patch_binary = file
    if not patch_binary:
        fail("Could not find patch binary.")
    return [DefaultInfo(files=depset([patch_binary]))]

find_patch_executable = rule(
    implementation = _find_patch_executable_impl,
    attrs = {
        "src": attr.label(
            mandatory = True,
        ),
    },
)
