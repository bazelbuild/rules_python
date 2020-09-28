def _mangle_name(str):
    return str.replace('-', '__')

def _emit_string(str):
    return '"%s"' % str

def _emit_string_list(items):
    return '[%s]' % ','.join([_emit_string(x) for x in items])

def _emit_package_build(rctx, pkg, name, deps):
    pkg = _mangle_name(pkg.lower())
    name = _mangle_name(name.lower())

    rctx.execute(["mkdir", "-p", pkg])
    rctx.file("%s/BUILD.bazel" % pkg, content="""\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = {name},
    deps = {deps},
)
    """.format(
        name = _emit_string(name),
        deps = _emit_string_list(deps),
    ))

def _py_external_package_impl(rctx):
    package_name = _mangle_name(rctx.attr.package_name.lower())

    if rctx.attr.url:
        archive = "sdist.tgz"

        rctx.download(
            url = rctx.attr.url,
            sha256 = rctx.attr.sha256,
            output = archive
        )
    elif rctx.attr.archive:
        archive = rctx.path(rctx.attr.archive)
    else:
        fail("either url or archive must be specified")

    rctx.execute(["mkdir", "-p", "source"])
    rctx.execute(["tar", "xzf", archive, "--strip-components", "1", "-C", "source"])

    rctx.file("BUILD.bazel", content="""\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python/private:py_wheel_library.bzl", "py_wheel_library")

py_wheel_library(
    name = {name},
    srcs = glob(["source/**/*"]),
    root = "source",
    deps = {deps},
    build_deps = {build_deps},
)
    """.format(
        name = _emit_string(package_name),
        deps = _emit_string_list(rctx.attr.deps),
        build_deps = _emit_string_list(rctx.attr.build_deps),
    ))

    wheel_target = "//:%s" % package_name

    _emit_package_build(rctx, package_name, package_name, [wheel_target])

    for extra, deps in rctx.attr.extras.items():
        pkg = '%s/%s' % (package_name, extra)

        _emit_package_build(rctx, pkg, extra, [wheel_target] + deps)

py_external_package = repository_rule(
    implementation = _py_external_package_impl,
    attrs = {
        "package_name": attr.string(
            mandatory = True,
        ),
        "url": attr.string(),
        "archive": attr.label(),
        "sha256": attr.string(),
        "deps": attr.string_list(default = []),
        "build_deps": attr.string_list(default = []),
        "extras": attr.string_list_dict(default = {}),
    },
)
