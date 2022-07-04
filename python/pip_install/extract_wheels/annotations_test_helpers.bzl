"""Helper macros and rules for testing the `annotations` module of `extract_wheels`"""

load("//python:pip.bzl", _package_annotation = "package_annotation")

package_annotation = _package_annotation

def _package_annotations_file_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".annotations.json")

    annotations = {package: json.decode(data) for (package, data) in ctx.attr.annotations.items()}
    ctx.actions.write(
        output = output,
        content = json.encode_indent(annotations, indent = " " * 4),
    )

    return DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )

package_annotations_file = rule(
    implementation = _package_annotations_file_impl,
    doc = (
        "Consumes `package_annotation` definitions in the same way " +
        "`pip_repository` rules do to produce an annotations file."
    ),
    attrs = {
        "annotations": attr.string_dict(
            doc = "See `@rules_python//python:pip.bzl%package_annotation",
            mandatory = True,
        ),
    },
)
