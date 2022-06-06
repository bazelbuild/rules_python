"""
py_test entrypoint generation
"""

def _py_pytest_main_impl(ctx):
    substitutions = {
        "$$FLAGS$$": ", ".join(['"{}"'.format(f) for f in ctx.attr.args]).strip(),
        "$$CHDIR$$": "os.chdir('{}')".format(ctx.attr.chdir) if ctx.attr.chdir else "",
    }

    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = dict(substitutions, **ctx.var),
        is_executable = False,
    )

_py_pytest_main = rule(
    implementation = _py_pytest_main_impl,
    attrs = {
        "args": attr.string_list(
            doc = "Additional arguments to pass to pytest.",
        ),
        "chdir": attr.string(
            doc = "A path to a directory to chdir when the test starts.",
            mandatory = False,
        ),
        "out": attr.output(
            doc = "The output file.",
            mandatory = True,
        ),
        "template": attr.label(
            allow_single_file = True,
            default = "//python/py_pytest_main:pytest.tmpl.py",
        ),
    },    
)

def py_pytest_main(name, **kwargs):
    """py_pytest_main wraps the template rendering target and the final py_library.

    Args:
        name: The name of the runable target that updates the test entry file.
        **kwargs: The extra arguments passed to the template rendering target.
    """

    test_main = name + ".py"
    tags = kwargs.pop("tags", [])
    visibility = kwargs.pop("visibility", [])

    _py_pytest_main(
        name = "%s_template" % name,
        out = test_main,
        tags = tags,
        visibility = visibility,
        **kwargs
    )

    native.py_library(
        name = name,
        srcs = [test_main],
        tags = tags,
        visibility = visibility,
    )
