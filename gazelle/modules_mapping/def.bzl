"""Definitions for the modules_mapping.json generation.

The modules_mapping.json file is a mapping from Python modules to the wheel
names that provide those modules. It is used for determining which wheel
distribution should be used in the `deps` attribute of `py_*` targets.

This mapping is necessary when reading Python import statements and determining
if they are provided by third-party dependencies. Most importantly, when the
module name doesn't match the wheel distribution name.
"""

def _modules_mapping_impl(ctx):
    modules_mapping = ctx.actions.declare_file(ctx.attr.modules_mapping_name)
    args = ctx.actions.args()
    args.add(modules_mapping.path)
    args.add_all([whl.path for whl in ctx.files.wheels])
    ctx.actions.run(
        inputs = ctx.files.wheels,
        outputs = [modules_mapping],
        executable = ctx.executable._generator,
        arguments = [args],
        use_default_shell_env = False,
    )
    return [DefaultInfo(files = depset([modules_mapping]))]

modules_mapping = rule(
    _modules_mapping_impl,
    attrs = {
        "modules_mapping_name": attr.string(
            default = "modules_mapping.json",
            doc = "The name for the output JSON file.",
            mandatory = False,
        ),
        "wheels": attr.label_list(
            allow_files = True,
            doc = "The list of wheels, usually the 'all_whl_requirements' from @<pip_repository>//:requirements.bzl",
            mandatory = True,
        ),
        "_generator": attr.label(
            cfg = "host",
            default = "//gazelle/modules_mapping:generator",
            executable = True,
        ),
    },
    doc = "Creates a modules_mapping.json file for mapping module names to wheel distribution names.",
)
