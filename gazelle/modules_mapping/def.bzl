"""Definitions for the modules_mapping.json generation.

The modules_mapping.json file is a mapping from Python modules to the wheel
names that provide those modules. It is used for determining which wheel
distribution should be used in the `deps` attribute of `py_*` targets.

This mapping is necessary when reading Python import statements and determining
if they are provided by third-party dependencies. Most importantly, when the
module name doesn't match the wheel distribution name.

Currently, this module only works with requirements.txt files locked using
pip-tools (https://github.com/jazzband/pip-tools) with hashes. This is necessary
in order to keep downloaded wheels in the Bazel cache. Also, the
modules_mapping rule does not consider extras as specified by PEP 508.
"""

# _modules_mapping_impl is the root entry for the modules_mapping rule
# implementation.
def _modules_mapping_impl(rctx):
    requirements_data = rctx.read(rctx.attr.requirements)
    python_interpreter = _get_python_interpreter(rctx)
    pythonpath = "{}/__pythonpath".format(rctx.path(""))
    res = rctx.execute(
        [
            python_interpreter,
            "-m",
            "pip",
            "--verbose",
            "--isolated",
            "install",
            "--target={}".format(pythonpath),
            "--upgrade",
            "--no-build-isolation",
            "--no-cache-dir",
            "--disable-pip-version-check",
            "--index-url={}".format(rctx.attr.pip_index_url),
            "build=={}".format(rctx.attr.build_wheel_version),
            "setuptools=={}".format(rctx.attr.setuptools_wheel_version),
        ],
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.install_build_timeout,
    )
    if res.return_code != 0:
        fail(res.stderr)
    parsed_requirements = _parse_requirements_txt(requirements_data)
    wheels = _get_wheels(rctx, python_interpreter, pythonpath, parsed_requirements)
    res = rctx.execute(
        [
            python_interpreter,
            rctx.path(rctx.attr._generator),
        ] + wheels,
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.generate_timeout,
    )
    if res.return_code != 0:
        fail(res.stderr)
    rctx.file("modules_mapping.json", content = res.stdout)
    rctx.file("print.sh", content = "#!/usr/bin/env bash\ncat $1", executable = True)
    rctx.file("BUILD", """\
exports_files(["modules_mapping.json"])

sh_binary(
    name = "print",
    srcs = ["print.sh"],
    data = [":modules_mapping.json"],
    args = ["$(rootpath :modules_mapping.json)"],
)
""")

# _get_python_interpreter determines whether the system or the user-provided
# Python interpreter should be used and returns the path to be called.
def _get_python_interpreter(rctx):
    if rctx.attr.python_interpreter == None:
        return "python"
    return rctx.path(rctx.attr.python_interpreter)

# _parse_requirements_txt parses the requirements.txt data into structs with the
# information needed to download them using Bazel.
def _parse_requirements_txt(data):
    result = []
    lines = data.split("\n")
    current_requirement = ""
    continue_previous_line = False
    for line in lines:
        # Ignore empty lines and comments.
        if len(line) == 0 or line.startswith("#"):
            continue

        line = line.strip()

        stripped_backslash = False
        if line.endswith("\\"):
            line = line[:-1]
            stripped_backslash = True

        # If this line is a continuation of the previous one, append the current
        # line to the current requirement being processed, otherwise, start a
        # new requirement.
        if continue_previous_line:
            current_requirement += line
        else:
            current_requirement = line

        # Control whether the next line in the requirements.txt should be a
        # continuation of the current requirement being processed or not.
        continue_previous_line = stripped_backslash
        if not continue_previous_line:
            result.append(_parse_requirement(current_requirement))
    return result

# _parse_requirement parses a single requirement line.
def _parse_requirement(requirement_line):
    split = requirement_line.split("==")
    requirement = {}

    # Removing the extras (https://www.python.org/dev/peps/pep-0508/#extras)
    # from the requirement name is fine since it's expected that the
    # requirements.txt was compiled with pip-tools, which includes the extras as
    # direct dependencies.
    name = _remove_extras_from_name(split[0])
    requirement["name"] = name
    if len(split) == 1:
        return struct(**requirement)
    split = split[1].split(" ")
    requirement["version"] = split[0]
    if len(split) == 1:
        return struct(**requirement)
    args = split[1:]
    hashes = []
    for arg in args:
        arg = arg.strip()

        # Skip empty arguments.
        if len(arg) == 0:
            continue

        # Halt processing if it hits a comment.
        if arg.startswith("#"):
            break
        if arg.startswith("--hash="):
            hashes.append(arg[len("--hash="):])
    requirement["hashes"] = hashes
    return struct(**requirement)

# _remove_extras_from_name removes the [extras] from a requirement.
# https://www.python.org/dev/peps/pep-0508/#extras
def _remove_extras_from_name(name):
    bracket_index = name.find("[")
    if bracket_index == -1:
        return name
    return name[:bracket_index]

# _get_wheels returns the wheel distributions for the given requirements. It
# uses a few different strategies depending on whether compiled wheel
# distributions exist on the remote index or not. The order in which it
# operates:
#
#   1. Try to use the platform-independent compiled wheel (*-none-any.whl).
#   2. Try to use the first match of the linux-dependent compiled wheel from the
#      sorted releases list. This is valid as it's deterministic and the Python
#      extension for Gazelle doesn't support other platform-specific wheels
#      (one must use manual means to accomplish platform-specific dependency
#      resolution).
#   3. Use the published source for the wheel.
def _get_wheels(rctx, python_interpreter, pythonpath, requirements):
    wheels = []
    to_build = []
    for requirement in requirements:
        if not hasattr(requirement, "hashes"):
            if hasattr(requirement, "name") and requirement.name.startswith("#"):
                # This is a comment in the requirements file.
                continue
            else:
                fail("missing requirement hash for {}-{}: use pip-tools to produce a locked file".format(
                    requirement.name,
                    requirement.version,
                ))

        wheel = {}
        wheel["name"] = requirement.name

        requirement_info_url = "{index_base}/{name}/{version}/json".format(
            index_base = rctx.attr.index_base,
            name = requirement.name,
            version = requirement.version,
        )
        requirement_info_path = "{}_info.json".format(requirement.name)

        # TODO(f0rmiga): if the logs are too spammy, use rctx.execute with
        # Python to perform the downloads since it's impossible to get the
        # checksums of these JSON files and there's no option to mute Bazel
        # here.
        rctx.download(requirement_info_url, output = requirement_info_path)
        requirement_info = json.decode(rctx.read(requirement_info_path))
        if requirement.version in requirement_info["releases"]:
            wheel["version"] = requirement.version
        elif requirement.version.endswith(".0") and requirement.version[:-len(".0")] in requirement_info["releases"]:
            wheel["version"] = requirement.version[:-len(".0")]
        else:
            fail("missing requirement version \"{}\" for wheel \"{}\" in fetched releases: available {}".format(
                requirement.version,
                requirement.name,
                [version for version in requirement_info["releases"]],
            ))
        releases = sorted(requirement_info["releases"][wheel["version"]], key = _sort_release_by_url)
        (wheel_url, sha256) = _search_url(releases, "-none-any.whl")

        # TODO(f0rmiga): handle PEP 600.
        # https://www.python.org/dev/peps/pep-0600/
        if not wheel_url:
            # Search for the Linux tag as defined in PEP 599.
            (wheel_url, sha256) = _search_url(releases, "manylinux2014_x86_64")
        if not wheel_url:
            # Search for the Linux tag as defined in PEP 571.
            (wheel_url, sha256) = _search_url(releases, "manylinux2010_x86_64")
        if not wheel_url:
            # Search for the Linux tag as defined in PEP 513.
            (wheel_url, sha256) = _search_url(releases, "manylinux1_x86_64")
        if not wheel_url:
            # Search for the MacOS tag
            (wheel_url, sha256) = _search_url(releases, "macosx_10_9_x86_64")

        if wheel_url:
            wheel_path = wheel_url.split("/")[-1]
            rctx.download(wheel_url, output = wheel_path, sha256 = sha256)
            wheel["path"] = wheel_path
        else:
            extension = ".tar.gz"
            (src_url, sha256) = _search_url(releases, extension)
            if not src_url:
                extension = ".zip"
                (src_url, sha256) = _search_url(releases, extension)
            if not src_url:
                fail("requirement URL for {}-{} not found".format(requirement.name, wheel["version"]))
            rctx.download_and_extract(src_url, sha256 = sha256)
            sanitized_name = requirement.name.lower().replace("-", "_")
            requirement_path = src_url.split("/")[-1]
            requirement_path = requirement_path[:-len(extension)]

            # The resulting filename for the .whl file is not feasible to
            # predict as it has too many variations, so we defer it to the
            # Python globing to find the right file name since only one .whl
            # file should be generated by the compilation.
            wheel_path = "{}/**/*.whl".format(requirement_path)
            wheel["path"] = wheel_path
            to_build.append(requirement_path)

        wheels.append(json.encode(wheel))

    if len(to_build) > 0:
        res = rctx.execute(
            [python_interpreter, rctx.path(rctx.attr._builder)] + to_build,
            quiet = rctx.attr.quiet,
            environment = {
                # To avoid use local "pip.conf"
                "HOME": str(rctx.path("").realpath),
                # Make uses of pip to use the requested index
                "PIP_INDEX_URL": rctx.attr.pip_index_url,
                "PYTHONPATH": pythonpath,
            },
        )
        if res.return_code != 0:
            fail(res.stderr)

    return wheels

# _sort_release_by_url is the custom function for the key property of the sorted
# releases.
def _sort_release_by_url(release):
    return release["url"]

# _search_url searches for a release in the list of releases that has a url
# matching the provided extension.
def _search_url(releases, extension):
    for release in releases:
        url = release["url"]
        if url.find(extension) >= 0:
            return (url, release["digests"]["sha256"])
    return (None, None)

modules_mapping = repository_rule(
    _modules_mapping_impl,
    attrs = {
        "build_wheel_version": attr.string(
            default = "0.5.1",
            doc = "The build wheel version.",
        ),
        "generate_timeout": attr.int(
            default = 30,
            doc = "The timeout for the generator.py command.",
        ),
        "index_base": attr.string(
            default = "https://pypi.org/pypi",
            doc = "The base URL used for querying releases data as JSON.",
        ),
        "install_build_timeout": attr.int(
            default = 30,
            doc = "The timeout for the `pip install build` command.",
        ),
        "pip_index_url": attr.string(
            default = "https://pypi.python.org/simple",
            doc = "The index URL used for any pip install actions",
        ),
        "python_interpreter": attr.label(
            allow_single_file = True,
            doc = "If set, uses the custom-built Python interpreter, otherwise, uses the system one.",
        ),
        "quiet": attr.bool(
            default = True,
            doc = "Toggle this attribute to get verbose output from this rule.",
        ),
        "requirements": attr.label(
            allow_single_file = True,
            doc = "The requirements.txt file with hashes locked using pip-tools.",
            mandatory = True,
        ),
        "setuptools_wheel_version": attr.string(
            default = "v57.5.0",
            doc = "The setuptools wheel version.",
        ),
        "_builder": attr.label(
            allow_single_file = True,
            default = "//gazelle/modules_mapping:builder.py",
        ),
        "_generator": attr.label(
            allow_single_file = True,
            default = "//gazelle/modules_mapping:generator.py",
        ),
    },
    doc = "Creates a modules_mapping.json file for mapping module names to wheel distribution names.",
)
