# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Implementation of py_wheel rule"

load("//python/private:stamp.bzl", "is_stamping_enabled")
load(":py_package.bzl", "py_package_lib")

PyWheelInfo = provider(
    doc = "Information about a wheel produced by `py_wheel`",
    fields = {
        "name_file": (
            "File: A file containing the canonical name of the wheel (after " +
            "stamping, if enabled)."
        ),
        "wheel": "File: The wheel file itself.",
    },
)

_distribution_attrs = {
    "abi": attr.string(
        default = "none",
        doc = "Python ABI tag. 'none' for pure-Python wheels.",
    ),
    "distribution": attr.string(
        mandatory = True,
        doc = """\
Name of the distribution.

This should match the project name onm PyPI. It's also the name that is used to
refer to the package in other packages' dependencies.

Workspace status keys are expanded using `{NAME}` format, for example:
 - `distribution = "package.{CLASSIFIER}"`
 - `distribution = "{DISTRIBUTION}"`

For the available keys, see https://bazel.build/docs/user-manual#workspace-status
""",
    ),
    "platform": attr.string(
        default = "any",
        doc = """\
Supported platform. Use 'any' for pure-Python wheel.

If you have included platform-specific data, such as a .pyd or .so
extension module, you will need to specify the platform in standard
pip format. If you support multiple platforms, you can define
platform constraints, then use a select() to specify the appropriate
specifier, eg:

`
platform = select({
    "//platforms:windows_x86_64": "win_amd64",
    "//platforms:macos_x86_64": "macosx_10_7_x86_64",
    "//platforms:linux_x86_64": "manylinux2014_x86_64",
})
`
""",
    ),
    "python_tag": attr.string(
        default = "py3",
        doc = "Supported Python version(s), eg `py3`, `cp35.cp36`, etc",
    ),
    "stamp": attr.int(
        doc = """\
Whether to encode build information into the wheel. Possible values:

- `stamp = 1`: Always stamp the build information into the wheel, even in \
[--nostamp](https://docs.bazel.build/versions/main/user-manual.html#flag--stamp) builds. \
This setting should be avoided, since it potentially kills remote caching for the target and \
any downstream actions that depend on it.

- `stamp = 0`: Always replace build information by constant values. This gives good build result caching.

- `stamp = -1`: Embedding of build information is controlled by the \
[--[no]stamp](https://docs.bazel.build/versions/main/user-manual.html#flag--stamp) flag.

Stamped targets are not rebuilt unless their dependencies change.
        """,
        default = -1,
        values = [1, 0, -1],
    ),
    "version": attr.string(
        mandatory = True,
        doc = """\
Version number of the package.

Note that this attribute supports stamp format strings as well as 'make variables'.
For example:
  - `version = "1.2.3-{BUILD_TIMESTAMP}"`
  - `version = "{BUILD_EMBED_LABEL}"`
  - `version = "$(VERSION)"`

Note that Bazel's output filename cannot include the stamp information, as outputs must be known
during the analysis phase and the stamp data is available only during the action execution.

The [`py_wheel`](/docs/packaging.md#py_wheel) macro produces a `.dist`-suffix target which creates a
`dist/` folder containing the wheel with the stamped name, suitable for publishing.

See [`py_wheel_dist`](/docs/packaging.md#py_wheel_dist) for more info.
""",
    ),
    "_stamp_flag": attr.label(
        doc = "A setting used to determine whether or not the `--stamp` flag is enabled",
        default = Label("//python/private:stamp"),
    ),
}

_requirement_attrs = {
    "extra_requires": attr.string_list_dict(
        doc = "List of optional requirements for this package",
    ),
    "requires": attr.string_list(
        doc = ("List of requirements for this package. See the section on " +
               "[Declaring required dependency](https://setuptools.readthedocs.io/en/latest/userguide/dependency_management.html#declaring-dependencies) " +
               "for details and examples of the format of this argument."),
    ),
}

_entrypoint_attrs = {
    "console_scripts": attr.string_dict(
        doc = """\
Deprecated console_script entry points, e.g. `{'main': 'examples.wheel.main:main'}`.

Deprecated: prefer the `entry_points` attribute, which supports `console_scripts` as well as other entry points.
""",
    ),
    "entry_points": attr.string_list_dict(
        doc = """\
entry_points, e.g. `{'console_scripts': ['main = examples.wheel.main:main']}`.
""",
    ),
}

_other_attrs = {
    "author": attr.string(
        doc = "A string specifying the author of the package.",
        default = "",
    ),
    "author_email": attr.string(
        doc = "A string specifying the email address of the package author.",
        default = "",
    ),
    "classifiers": attr.string_list(
        doc = "A list of strings describing the categories for the package. For valid classifiers see https://pypi.org/classifiers",
    ),
    "description_content_type": attr.string(
        doc = ("The type of contents in description_file. " +
               "If not provided, the type will be inferred from the extension of description_file. " +
               "Also see https://packaging.python.org/en/latest/specifications/core-metadata/#description-content-type"),
    ),
    "description_file": attr.label(
        doc = "A file containing text describing the package.",
        allow_single_file = True,
    ),
    "extra_distinfo_files": attr.label_keyed_string_dict(
        doc = "Extra files to add to distinfo directory in the archive.",
        allow_files = True,
    ),
    "homepage": attr.string(
        doc = "A string specifying the URL for the package homepage.",
        default = "",
    ),
    "license": attr.string(
        doc = "A string specifying the license of the package.",
        default = "",
    ),
    "project_urls": attr.string_dict(
        doc = ("A string dict specifying additional browsable URLs for the project and corresponding labels, " +
               "where label is the key and url is the value. " +
               'e.g `{{"Bug Tracker": "http://bitbucket.org/tarek/distribute/issues/"}}`'),
    ),
    "python_requires": attr.string(
        doc = (
            "Python versions required by this distribution, e.g. '>=3.5,<3.7'"
        ),
        default = "",
    ),
    "strip_path_prefixes": attr.string_list(
        default = [],
        doc = "path prefixes to strip from files added to the generated package",
    ),
    "summary": attr.string(
        doc = "A one-line summary of what the distribution does",
    ),
}

_PROJECT_URL_LABEL_LENGTH_LIMIT = 32
_DESCRIPTION_FILE_EXTENSION_TO_TYPE = {
    "md": "text/markdown",
    "rst": "text/x-rst",
}
_DEFAULT_DESCRIPTION_FILE_TYPE = "text/plain"

def _escape_filename_distribution_name(name):
    """Escape the distribution name component of a filename.

    See https://packaging.python.org/en/latest/specifications/binary-distribution-format/#escaping-and-unicode
    and https://packaging.python.org/en/latest/specifications/name-normalization/.

    Apart from the valid names according to the above, we also accept
    '{' and '}', which may be used as placeholders for stamping.
    """
    escaped = ""
    for character in name.elems():
        if character.isalnum() or character in ["{", "}"]:
            escaped += character.lower()
        elif character in ["-", "_", "."]:
            if escaped == "":
                fail(
                    "A valid name must start with a letter or number.",
                    "Name '%s' does not." % name,
                )
            elif escaped.endswith("_"):
                pass
            else:
                escaped += "_"
        else:
            fail(
                "A valid name consists only of ASCII letters ",
                "and numbers, period, underscore and hyphen.",
                "Name '%s' has bad character '%s'." % (name, character),
            )
    if escaped.endswith("_"):
        fail(
            "A valid name must end with a letter or number.",
            "Name '%s' does not." % name,
        )
    return escaped

def normalize_pep440(version):
    """Escape the version component of a filename.

    See https://packaging.python.org/en/latest/specifications/binary-distribution-format/#escaping-and-unicode
    and https://peps.python.org/pep-0440/

    Args:
      version: version string to be normalized according to PEP 440.

    Returns:
      string containing the normalized version.
    """

    version = version.strip()  # PEP 440: Leading and Trailing Whitespace
    contexts = []

    def open_context(start):
        """Open an new parsing context.

        If the current parsing step succeeds, call close_context().
        If the current parsing step fails, call contexts.pop() to
        go back to how it was before we opened a new context.

        Args:
          start: index into `version` indicating where the current
            parsing step starts.
        """
        contexts.append({"norm": "", "start": start})
        return contexts[-1]

    def close_context():
        """Close the current context successfully and merge the results."""
        finished = contexts.pop()
        contexts[-1]["norm"] += finished["norm"]
        contexts[-1]["start"] = finished["start"]

    def is_(reference):
        """Predicate testing a token for equality with `reference`."""
        return lambda token: token == reference

    def is_not(reference):
        """Predicate testing a token for inequality with `reference`."""
        return lambda token: token != reference

    def in_(reference):
        """Predicate testing if a token is in the list `reference`."""
        return lambda token: token in reference

    def accept(predicate, value):
        """If `predicate` matches the next token, accept the token.

        Accepting the token means adding it (according to `value`) to
        the running results maintained in context["norm"] and
        advancing the cursor in context["start"] to the next token in
        `version`.

        Args:
          predicate: function taking a token and returning a boolean
            saying if we want to accept the token.
          value: the string to add if there's a match, or, if `value`
            is a function, the function to apply to the current token
            to get the string to add.

        Returns:
          whether a token was accepted.
        """

        context = contexts[-1]

        if context["start"] >= len(version):
            return False

        token = version[context["start"]]

        if predicate(token):
            if type(value) in ["function", "builtin_function_or_method"]:
                value = value(token)

            context["norm"] += value
            context["start"] += 1
            return True

        return False

    def accept_placeholder():
        """Accept a Bazel placeholder.

        Placeholders aren't actually part of PEP 440, but are used for
        stamping purposes. A placeholder might be
        ``{BUILD_TIMESTAMP}``, for instance. We'll accept these as
        they are, assuming they will expand to something that makes
        sense where they appear. Before the stamping has happened, a
        resulting wheel file name containing a placeholder will not
        actually be valid.

        """
        context = open_context(contexts[-1]["start"])

        if not accept(is_("{"), str):
            contexts.pop()
            return False

        start = context["start"]
        for _ in range(start, len(version) + 1):
            if not accept(is_not("}"), str):
                break

        if not accept(is_("}"), str):
            contexts.pop()
            return False

        close_context()
        return True

    def accept_digits():
        """Accept multiple digits (or placeholders)."""

        def isdigit(token):
            return token.isdigit()

        context = open_context(contexts[-1]["start"])
        start = context["start"]

        for i in range(start, len(version) + 1):
            if not accept(isdigit, str) and not accept_placeholder():
                if i - start >= 1:
                    if context["norm"].isdigit():
                        # PEP 440: Integer Normalization
                        context["norm"] = str(int(context["norm"]))
                    close_context()
                    return True
                break

        contexts.pop()
        return False

    def accept_string(string, replacement):
        """Accept a `string` in the input. Output `replacement`."""
        context = open_context(contexts[-1]["start"])

        for character in string.elems():
            if not accept(in_([character, character.upper()]), ""):
                contexts.pop()
                return False

        context["norm"] = replacement

        close_context()
        return True

    def accept_alnum():
        """Accept an alphanumeric sequence."""

        def isalnum(token):
            return token.isalnum()

        # PEP 440: Case sensitivity
        def lower(token):
            return token.lower()

        context = open_context(contexts[-1]["start"])
        start = context["start"]

        for i in range(start, len(version) + 1):
            if not accept(isalnum, lower) and not accept_placeholder():
                if i - start >= 1:
                    close_context()
                    return True
                break

        contexts.pop()
        return False

    def accept_dot_number():
        """Accept a dot followed by digits."""
        open_context(contexts[-1]["start"])

        if accept(is_("."), ".") and accept_digits():
            close_context()
            return True
        else:
            contexts.pop()
            return False

    def accept_dot_number_sequence():
        """Accept a sequence of dot+digits."""
        context = contexts[-1]
        start = context["start"]
        i = start

        for i in range(start, len(version) + 1):
            if not accept_dot_number():
                break
        return i - start >= 1

    def accept_separator_alnum():
        """Accept a separator followed by an alphanumeric string."""
        open_context(contexts[-1]["start"])

        # PEP 440: Local version segments
        if (
            accept(in_([".", "-", "_"]), ".") and
            (accept_digits() or accept_alnum())
        ):
            close_context()
            return True

        contexts.pop()
        return False

    def accept_separator_alnum_sequence():
        """Accept a sequence of separator+alphanumeric."""
        context = contexts[-1]
        start = context["start"]
        i = start

        for i in range(start, len(version) + 1):
            if not accept_separator_alnum():
                break

        return i - start >= 1

    def accept_epoch():
        """PEP 440: Version epochs."""
        context = open_context(contexts[-1]["start"])
        if accept_digits() and accept(is_("!"), "!"):
            if context["norm"] == "0!":
                contexts.pop()
                contexts[-1]["start"] = context["start"]
            else:
                close_context()
            return True
        else:
            contexts.pop()
            return False

    def accept_release():
        """Accept the release segment, numbers separated by dots."""
        open_context(contexts[-1]["start"])

        if not accept_digits():
            contexts.pop()
            return False

        accept_dot_number_sequence()
        close_context()
        return True

    def accept_pre_l():
        """PEP 440: Pre-release spelling."""
        open_context(contexts[-1]["start"])

        if (
            accept_string("alpha", "a") or
            accept_string("a", "a") or
            accept_string("beta", "b") or
            accept_string("b", "b") or
            accept_string("c", "rc") or
            accept_string("preview", "rc") or
            accept_string("pre", "rc") or
            accept_string("rc", "rc")
        ):
            close_context()
            return True
        else:
            contexts.pop()
            return False

    def accept_prerelease():
        """PEP 440: Pre-releases."""
        context = open_context(contexts[-1]["start"])

        # PEP 440: Pre-release separators
        accept(in_(["-", "_", "."]), "")

        if not accept_pre_l():
            contexts.pop()
            return False

        accept(in_(["-", "_", "."]), "")

        if not accept_digits():
            # PEP 440: Implicit pre-release number
            context["norm"] += "0"

        close_context()
        return True

    def accept_implicit_postrelease():
        """PEP 440: Implicit post releases."""
        context = open_context(contexts[-1]["start"])

        if accept(is_("-"), "") and accept_digits():
            context["norm"] = ".post" + context["norm"]
            close_context()
            return True

        contexts.pop()
        return False

    def accept_explicit_postrelease():
        """PEP 440: Post-releases."""
        context = open_context(contexts[-1]["start"])

        # PEP 440: Post release separators
        if not accept(in_(["-", "_", "."]), "."):
            context["norm"] += "."

        # PEP 440: Post release spelling
        if (
            accept_string("post", "post") or
            accept_string("rev", "post") or
            accept_string("r", "post")
        ):
            accept(in_(["-", "_", "."]), "")

            if not accept_digits():
                # PEP 440: Implicit post release number
                context["norm"] += "0"

            close_context()
            return True

        contexts.pop()
        return False

    def accept_postrelease():
        """PEP 440: Post-releases."""
        open_context(contexts[-1]["start"])

        if accept_implicit_postrelease() or accept_explicit_postrelease():
            close_context()
            return True

        contexts.pop()
        return False

    def accept_devrelease():
        """PEP 440: Developmental releases."""
        context = open_context(contexts[-1]["start"])

        # PEP 440: Development release separators
        if not accept(in_(["-", "_", "."]), "."):
            context["norm"] += "."

        if accept_string("dev", "dev"):
            accept(in_(["-", "_", "."]), "")

            if not accept_digits():
                # PEP 440: Implicit development release number
                context["norm"] += "0"

            close_context()
            return True

        contexts.pop()
        return False

    def accept_local():
        """PEP 440: Local version identifiers."""
        open_context(contexts[-1]["start"])

        if accept(is_("+"), "+") and accept_alnum():
            accept_separator_alnum_sequence()
            close_context()
            return True

        contexts.pop()
        return False

    open_context(0)
    accept(is_("v"), "")  # PEP 440: Preceding v character
    accept_epoch()
    accept_release()
    accept_prerelease()
    accept_postrelease()
    accept_devrelease()
    accept_local()
    if version[contexts[-1]["start"]:]:
        fail(
            "Failed to parse PEP 440 version identifier '%s'." % version,
            "Parse error at '%s'" % version[contexts[-1]["start"]:],
        )
    return contexts[-1]["norm"]

def _escape_filename_segment(segment):
    """Escape a segment of the wheel filename.

    See https://www.python.org/dev/peps/pep-0427/#escaping-and-unicode
    """

    # TODO: this is wrong, isalnum replaces non-ascii letters, while we should
    # not replace them.
    # TODO: replace this with a regexp once starlark supports them.
    escaped = ""
    for character in segment.elems():
        # isalnum doesn't handle unicode characters properly.
        if character.isalnum() or character == ".":
            escaped += character
        elif not escaped.endswith("_"):
            escaped += "_"
    return escaped

def _replace_make_variables(flag, ctx):
    """Replace $(VERSION) etc make variables in flag"""
    if "$" in flag:
        for varname, varsub in ctx.var.items():
            flag = flag.replace("$(%s)" % varname, varsub)
    return flag

def _input_file_to_arg(input_file):
    """Converts a File object to string for --input_file argument to wheelmaker"""
    return "%s;%s" % (py_package_lib.path_inside_wheel(input_file), input_file.path)

def _py_wheel_impl(ctx):
    abi = _replace_make_variables(ctx.attr.abi, ctx)
    python_tag = _replace_make_variables(ctx.attr.python_tag, ctx)
    version = _replace_make_variables(ctx.attr.version, ctx)

    outfile = ctx.actions.declare_file("-".join([
        _escape_filename_distribution_name(ctx.attr.distribution),
        normalize_pep440(version),
        _escape_filename_segment(python_tag),
        _escape_filename_segment(abi),
        _escape_filename_segment(ctx.attr.platform),
    ]) + ".whl")

    name_file = ctx.actions.declare_file(ctx.label.name + ".name")

    inputs_to_package = depset(
        direct = ctx.files.deps,
    )

    # Inputs to this rule which are not to be packaged.
    # Currently this is only the description file (if used).
    other_inputs = []

    # Wrap the inputs into a file to reduce command line length.
    packageinputfile = ctx.actions.declare_file(ctx.attr.name + "_target_wrapped_inputs.txt")
    content = ""
    for input_file in inputs_to_package.to_list():
        content += _input_file_to_arg(input_file) + "\n"
    ctx.actions.write(output = packageinputfile, content = content)
    other_inputs.append(packageinputfile)

    args = ctx.actions.args()
    args.add("--name", ctx.attr.distribution)
    args.add("--version", version)
    args.add("--python_tag", python_tag)
    args.add("--abi", abi)
    args.add("--platform", ctx.attr.platform)
    args.add("--out", outfile)
    args.add("--name_file", name_file)
    args.add_all(ctx.attr.strip_path_prefixes, format_each = "--strip_path_prefix=%s")

    # Pass workspace status files if stamping is enabled
    if is_stamping_enabled(ctx.attr):
        args.add("--volatile_status_file", ctx.version_file)
        args.add("--stable_status_file", ctx.info_file)
        other_inputs.extend([ctx.version_file, ctx.info_file])

    args.add("--input_file_list", packageinputfile)

    # Note: Description file and version are not embedded into metadata.txt yet,
    # it will be done later by wheelmaker script.
    metadata_file = ctx.actions.declare_file(ctx.attr.name + ".metadata.txt")
    metadata_contents = ["Metadata-Version: 2.1"]
    metadata_contents.append("Name: %s" % ctx.attr.distribution)

    if ctx.attr.author:
        metadata_contents.append("Author: %s" % ctx.attr.author)
    if ctx.attr.author_email:
        metadata_contents.append("Author-email: %s" % ctx.attr.author_email)
    if ctx.attr.homepage:
        metadata_contents.append("Home-page: %s" % ctx.attr.homepage)
    if ctx.attr.license:
        metadata_contents.append("License: %s" % ctx.attr.license)
    if ctx.attr.description_content_type:
        metadata_contents.append("Description-Content-Type: %s" % ctx.attr.description_content_type)
    elif ctx.attr.description_file:
        # infer the content type from description file extension.
        description_file_type = _DESCRIPTION_FILE_EXTENSION_TO_TYPE.get(
            ctx.file.description_file.extension,
            _DEFAULT_DESCRIPTION_FILE_TYPE,
        )
        metadata_contents.append("Description-Content-Type: %s" % description_file_type)
    if ctx.attr.summary:
        metadata_contents.append("Summary: %s" % ctx.attr.summary)

    for label, url in sorted(ctx.attr.project_urls.items()):
        if len(label) > _PROJECT_URL_LABEL_LENGTH_LIMIT:
            fail("`label` {} in `project_urls` is too long. It is limited to {} characters.".format(len(label), _PROJECT_URL_LABEL_LENGTH_LIMIT))
        metadata_contents.append("Project-URL: %s, %s" % (label, url))

    for c in ctx.attr.classifiers:
        metadata_contents.append("Classifier: %s" % c)

    if ctx.attr.python_requires:
        metadata_contents.append("Requires-Python: %s" % ctx.attr.python_requires)
    for requirement in ctx.attr.requires:
        metadata_contents.append("Requires-Dist: %s" % requirement)

    for option, option_requirements in sorted(ctx.attr.extra_requires.items()):
        metadata_contents.append("Provides-Extra: %s" % option)
        for requirement in option_requirements:
            metadata_contents.append(
                "Requires-Dist: %s; extra == '%s'" % (requirement, option),
            )
    ctx.actions.write(
        output = metadata_file,
        content = "\n".join(metadata_contents) + "\n",
    )
    other_inputs.append(metadata_file)
    args.add("--metadata_file", metadata_file)

    # Merge console_scripts into entry_points.
    entrypoints = dict(ctx.attr.entry_points)  # Copy so we can mutate it
    if ctx.attr.console_scripts:
        # Copy a console_scripts group that may already exist, so we can mutate it.
        console_scripts = list(entrypoints.get("console_scripts", []))
        entrypoints["console_scripts"] = console_scripts
        for name, ref in ctx.attr.console_scripts.items():
            console_scripts.append("{name} = {ref}".format(name = name, ref = ref))

    # If any entry_points are provided, construct the file here and add it to the files to be packaged.
    # see: https://packaging.python.org/specifications/entry-points/
    if entrypoints:
        lines = []
        for group, entries in sorted(entrypoints.items()):
            if lines:
                # Blank line between groups
                lines.append("")
            lines.append("[{group}]".format(group = group))
            lines += sorted(entries)
        entry_points_file = ctx.actions.declare_file(ctx.attr.name + "_entry_points.txt")
        content = "\n".join(lines)
        ctx.actions.write(output = entry_points_file, content = content)
        other_inputs.append(entry_points_file)
        args.add("--entry_points_file", entry_points_file)

    if ctx.attr.description_file:
        description_file = ctx.file.description_file
        args.add("--description_file", description_file)
        other_inputs.append(description_file)

    for target, filename in ctx.attr.extra_distinfo_files.items():
        target_files = target.files.to_list()
        if len(target_files) != 1:
            fail(
                "Multi-file target listed in extra_distinfo_files %s",
                filename,
            )
        other_inputs.extend(target_files)
        args.add(
            "--extra_distinfo_file",
            filename + ";" + target_files[0].path,
        )

    ctx.actions.run(
        inputs = depset(direct = other_inputs, transitive = [inputs_to_package]),
        outputs = [outfile, name_file],
        arguments = [args],
        executable = ctx.executable._wheelmaker,
        progress_message = "Building wheel {}".format(ctx.label),
    )
    return [
        DefaultInfo(
            files = depset([outfile]),
            runfiles = ctx.runfiles(files = [outfile]),
        ),
        PyWheelInfo(
            wheel = outfile,
            name_file = name_file,
        ),
    ]

def _concat_dicts(*dicts):
    result = {}
    for d in dicts:
        result.update(d)
    return result

py_wheel_lib = struct(
    implementation = _py_wheel_impl,
    attrs = _concat_dicts(
        {
            "deps": attr.label_list(
                doc = """\
Targets to be included in the distribution.

The targets to package are usually `py_library` rules or filesets (for packaging data files).

Note it's usually better to package `py_library` targets and use
`entry_points` attribute to specify `console_scripts` than to package
`py_binary` rules. `py_binary` targets would wrap a executable script that
tries to locate `.runfiles` directory which is not packaged in the wheel.
""",
            ),
            "_wheelmaker": attr.label(
                executable = True,
                cfg = "exec",
                default = "//tools:wheelmaker",
            ),
        },
        _distribution_attrs,
        _requirement_attrs,
        _entrypoint_attrs,
        _other_attrs,
    ),
)

py_wheel = rule(
    implementation = py_wheel_lib.implementation,
    doc = """\
Internal rule used by the [py_wheel macro](/docs/packaging.md#py_wheel).

These intentionally have the same name to avoid sharp edges with Bazel macros.
For example, a `bazel query` for a user's `py_wheel` macro expands to `py_wheel` targets,
in the way they expect.
""",
    attrs = py_wheel_lib.attrs,
)
