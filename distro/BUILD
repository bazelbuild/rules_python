load("@rules_pkg//:pkg.bzl", "pkg_tar")
load("@rules_pkg//releasing:defs.bzl", "print_rel_notes")
load("@rules_python//:version.bzl", "version")

package(
    default_visibility = ["//visibility:private"],
)

# Build the artifact to put on the github release page.
pkg_tar(
    name = "rules_python-%s" % version,
    srcs = [
        "//:distribution",
    ],
    extension = "tar.gz",
    # It is all source code, so make it read-only.
    mode = "0444",
    # Make it owned by root so it does not have the uid of the CI robot.
    owner = "0.0",
    package_dir = ".",
    strip_prefix = ".",
)

# TODO(brandjon): print_rel_notes doesn't appear to handle our use case of
# emitting an optional additional deps method from a different file. For now we
# manually adjust our release notes.
print_rel_notes(
    name = "relnotes",
    outs = ["relnotes.txt"],
    deps_method = "py_repositories",
    repo = "rules_python",
    setup_file = "python:repositories.bzl",
    version = version,
)
