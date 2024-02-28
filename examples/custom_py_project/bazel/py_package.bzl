"""custom implementation of py_package that filters out files that match */site-packages/*

"""

load("@rules_python//python:packaging.bzl", "PyRequrirementInfo", "PyRequrirementsInfo")

SITE_PACKAGES = "/site-packages/"
DIST_INFO_METADATA_SUFFIX = ".dist-info/METADATA"

def _py_package_impl(ctx):
    inputs = depset(
        transitive = [dep[DefaultInfo].data_runfiles.files for dep in ctx.attr.deps] +
                     [dep[DefaultInfo].default_runfiles.files for dep in ctx.attr.deps],
    )

    files = []
    requirements = []

    for input_file in inputs.to_list():
        filename = input_file.short_path
        if SITE_PACKAGES in filename:
            (_, _, suffix) = filename.partition(SITE_PACKAGES)
            if suffix.endswith(DIST_INFO_METADATA_SUFFIX):
                basename = suffix[0:len(suffix) - len(DIST_INFO_METADATA_SUFFIX)]
                name, version = basename.rsplit("-")
                if name and version:
                    requirements.append(PyRequrirementInfo(
                        name = name,
                        version = version,
                        specifier = "%s>=%s" % (name, version),
                    ))
        else:
            files.append(input_file)

    return [
        DefaultInfo(
            files = depset(direct = files),
        ),
        PyRequrirementsInfo(
            label = ctx.label,
            requirements = requirements,
        ),
    ]

py_package = rule(
    doc = """\
A rule to select all files in transitive dependencies of deps which
belong to given set of Python packages.

This rule is intended to be used as data dependency to py_wheel rule.
""",
    implementation = _py_package_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "",
        ),
    },
)
