"""This module provides the macros for performing a release.
"""

load("@io_bazel_rules_go//go:def.bzl", "go_binary")

PLATFORMS = [
    struct(os = "darwin", arch = "amd64", ext = "", gc_linkopts = ["-s", "-w"]),
    struct(os = "darwin", arch = "arm64", ext = "", gc_linkopts = ["-s", "-w"]),
    struct(os = "linux", arch = "amd64", ext = "", gc_linkopts = ["-s", "-w"]),
    struct(os = "linux", arch = "arm64", ext = "", gc_linkopts = ["-s", "-w"]),
    struct(os = "windows", arch = "amd64", ext = ".exe", gc_linkopts = []),
]

def multi_platform_binaries(name, embed, prefix = ""):
    """The multi_platform_binaries macro creates a go_binary for each platform.

    Args:
        name: the name of the filegroup containing all go_binary targets produced
            by this macro.
        embed: the list of targets passed to each go_binary target in this
            macro.
        prefix: an optional prefix added to the output Go binary file name.
    """
    targets = []
    for platform in PLATFORMS:
        target_name = "{}-{}-{}".format(name, platform.os, platform.arch)
        go_binary(
            name = target_name,
            out = "{}{}-{}_{}{}".format(prefix, name, platform.os, platform.arch, platform.ext),
            embed = embed,
            gc_linkopts = platform.gc_linkopts,
            goarch = platform.arch,
            goos = platform.os,
            pure = "on",
            visibility = ["//visibility:public"],
        )
        targets.append(Label("//{}:{}".format(native.package_name(), target_name)))

    native.filegroup(
        name = name,
        srcs = targets,
    )

def release(name, targets):
    """The release macro creates the artifact copier script.

    It's an executable script that copies all artifacts produced by the given
    targets into the provided destination. See .github/workflows/release.yml.

    Args:
        name: the name of the genrule.
        targets: a list of filegroups passed to the artifact copier.
    """
    native.genrule(
        name = name,
        srcs = targets,
        outs = ["release.sh"],
        executable = True,
        cmd = "./$(location //release:create_release.sh) {locations} > \"$@\"".format(
            locations = " ".join(["$(locations {})".format(target) for target in targets]),
        ),
        tools = ["//release:create_release.sh"],
    )
