"""
Provider definitions 
"""

# Modelled after the NodeContextInfo
PythonContextInfo = provider(
    doc = "Provides data about the build context, like config_setting's",
    fields = {
        "stamp": "If stamping is enabled",
    },
)

PYTHON_CONTEXT_ATTRS = {
    "python_context_data": attr.label(
        default = "@rules_python//python:python_context_data",
        providers = [PythonContextInfo],
        doc = """Provides info about the build context, such as stamping.
        
By default it reads from the bazel command line, such as the `--stamp` argument.
Use this to override values for this target, such as enabling or disabling stamping.
You can use the `python_context_data` rule in `@rules_python//python:context.bzl`
to create a PythonContextInfo.
""",
    ),
}
