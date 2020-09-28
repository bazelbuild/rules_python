# Copyright 2016 Google Inc. All Rights Reserved.
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

"""Build self-contained python executables."""

load("@rules_python//python:defs.bzl", "py_binary", "py_test")

DEFAULT_COMPILER = "@subpar//compiler:compiler.par"

def _static_prepend_workspace(path, workspace_name):
    """Given a path, prepend the workspace name as the parent directory"""

    # It feels like there should be an easier, less fragile way.
    if path.startswith("../"):
        # External workspace, for example
        # '../protobuf/python/google/protobuf/any_pb2.py'
        stored_path = path[len("../"):]
    elif path.startswith("external/"):
        # External workspace, for example
        # 'external/protobuf/python/__init__.py'
        stored_path = path[len("external/"):]
    else:
        # Main workspace, for example 'mypackage/main.py'
        stored_path = workspace_name + "/" + path
    return stored_path

def _prepend_workspace(path, ctx):
    return _static_prepend_workspace(path, ctx.workspace_name)

def _expand_manifest_input(file):
    return "%s:%s" % (_static_prepend_workspace(file.short_path, "@"), file.path)

def _expand_manifest_empty(file):
    return "%s:" % _static_prepend_workspace(file, "@")

def _parfile_impl(ctx):
    """Implementation of parfile() rule"""

    # Find the main entry point
    py_files = ctx.files.main
    if len(py_files) == 0:
        fail("Expected exactly one .py file, found none", "main")
    elif len(py_files) > 1:
        fail("Expected exactly one .py file, found these: [%s]" % py_files, "main")
    main_py_file = py_files[0]
    if main_py_file not in ctx.attr.src.data_runfiles.files.to_list():
        fail("Main entry point [%s] not listed in srcs" % main_py_file, "main")

    # Write the list to the manifest file
    runfiles = ctx.attr.src.default_runfiles
    sources_file = ctx.actions.declare_file(ctx.label.name + "_SOURCES")
    sources = depset(transitive = [runfiles.files])

    outer_args = ctx.actions.args()
    outer_args.add(ctx.workspace_name)
    outer_args.add(sources_file.path)

    # Make a manifest of files to store in the .par file.  The
    # runfiles manifest is not quite right, so we make our own.
    manifest_args = ctx.actions.args()
    manifest_args.use_param_file("%s", use_always=True)
    manifest_args.set_param_file_format("multiline")

    # First, add the zero-length __init__.py files
    manifest_args.add_all(
        runfiles.empty_filenames,
        map_each=_expand_manifest_empty,
        uniquify=True,
    )

    # Now add the regular (source and generated) files
    manifest_args.add_all(
        runfiles.files,
        map_each=_expand_manifest_input,
        expand_directories=True,
        uniquify=True,
    )

    # Now make a nice sorted list
    ctx.actions.run_shell(
        arguments = [outer_args, manifest_args],
        inputs = depset(transitive = [runfiles.files]),
        outputs = [sources_file],
        command = """
        set -euo pipefail

        WORKSPACE=$1
        OUTPUT=$2
        ARGS_FILE=$3

        filter_whitespace() {
            while read line; do
                OLDIFS=$IFS; IFS=':'; read -ra parts <<<"$line"; IFS=$OLDIFS

                target="${parts[0]}"
                source="${parts[1]:-}"

                if [[ "$target" == *" "* ]]; then
                    >&2 echo "Ignoring file with whitespace in filename: $target"
                    continue
                fi

                echo "${target} ${source}"
            done
        }

        cat "$ARGS_FILE" \
            | filter_whitespace \
            | sed "s/^@/$1/g" \
            | sed "s/:/ /g" \
            | sort -u > $OUTPUT
        """,
    )

    # Find the list of directories to add to sys.path
    import_roots = ctx.attr.src[PyInfo].imports.to_list()

    zip_safe = ctx.attr.zip_safe

    # Assemble command line for .par compiler
    args = ctx.attr.compiler_args + [
        "--manifest_file",
        sources_file.path,
        "--output_par",
        ctx.outputs.executable.path,
        "--stub_file",
        ctx.attr.src.files_to_run.executable.path,
        "--zip_safe",
        str(zip_safe),
    ]

    for import_root in import_roots:
        args.extend(['--import_root', import_root])

    args.append(main_py_file.path)

    # Run compiler
    ctx.actions.run(
        inputs = depset(direct = [sources_file], transitive = [sources]),
        tools = [ctx.attr.src.files_to_run.executable],
        outputs = [ctx.outputs.executable],
        progress_message = "Building par file %s" % ctx.label,
        executable = ctx.executable.compiler,
        arguments = args,
        mnemonic = "PythonCompile",
        use_default_shell_env = True,
    )

    # .par file itself has no runfiles and no providers
    return []

parfile_attrs = {
    "src": attr.label(mandatory = True),
    "main": attr.label(
        mandatory = True,
        allow_single_file = True,
    ),
    "imports": attr.string_list(default = []),
    "default_python_version": attr.string(mandatory = True),
    "compiler": attr.label(
        default = Label(DEFAULT_COMPILER),
        executable = True,
        cfg = "host",
    ),
    "compiler_args": attr.string_list(default = []),
    "zip_safe": attr.bool(default = True),
}

# Rule to create a parfile given a py_binary() as input
parfile = rule(
    attrs = parfile_attrs,
    executable = True,
    implementation = _parfile_impl,
    test = False,
)
"""A self-contained, single-file Python program, with a .par file extension.

You probably want to use par_binary() instead of this.

Args:
  src: A py_binary() target
  main: The name of the source file that is the main entry point of
    the application.

    See [py_binary.main](http://www.bazel.io/docs/be/python.html#py_binary.main)

  imports: List of import directories to be added to the PYTHONPATH.

    See [py_binary.imports](http://www.bazel.io/docs/be/python.html#py_binary.imports)

  default_python_version: A string specifying the default Python major version to use when building this par file.

    See [py_binary.default_python_version](http://www.bazel.io/docs/be/python.html#py_binary.default_python_version)

  compiler: Internal use only.

  zip_safe: Whether to import Python code and read datafiles directly
            from the zip archive.  Otherwise, if False, all files are
            extracted to a temporary directory on disk each time the
            par file executes.

TODO(b/27502830): A directory foo.par.runfiles is also created. This
is a bug, don't use or depend on it.
"""

parfile_test = rule(
    attrs = parfile_attrs,
    executable = True,
    implementation = _parfile_impl,
    test = True,
)
"""Identical to par_binary, but the rule is marked as being a test.

You probably want to use par_test() instead of this.
"""

def par_binary(name, **kwargs):
    """An executable Python program.

    par_binary() is a drop-in replacement for py_binary() that also
    builds a self-contained, single-file executable for the
    application, with a .par file extension.

    The `name` attribute shouldn't include the `.par` file extension,
    it's added automatically.  So, for a rule like
    `par_binary(name="myname")`, build the file `myname.par` by doing
    `bazel build //mypackage:myname.par`

    See [py_binary](http://www.bazel.io/docs/be/python.html#py_binary)
    for arguments and usage.
    """
    compiler = kwargs.pop("compiler", None)
    compiler_args = kwargs.pop("compiler_args", [])
    zip_safe = kwargs.pop("zip_safe", True)
    py_binary(name = name, **kwargs)

    main = kwargs.get("main", name + ".py")
    imports = kwargs.get("imports")
    default_python_version = kwargs.get("default_python_version", "PY2")
    visibility = kwargs.get("visibility")
    testonly = kwargs.get("testonly", False)
    tags = kwargs.get("tags", [])
    parfile(
        compiler = compiler,
        compiler_args = compiler_args,
        default_python_version = default_python_version,
        imports = imports,
        main = main,
        name = name + ".par",
        src = name,
        testonly = testonly,
        visibility = visibility,
        zip_safe = zip_safe,
        tags = tags,
    )

def par_test(name, **kwargs):
    """An executable Python test.

    Just like par_binary, but for py_test instead of py_binary.  Useful if you
    specifically need to test a module's behaviour when used in a .par binary.
    """
    compiler = kwargs.pop("compiler", None)
    zip_safe = kwargs.pop("zip_safe", True)
    py_test(name = name, **kwargs)

    main = kwargs.get("main", name + ".py")
    imports = kwargs.get("imports")
    default_python_version = kwargs.get("default_python_version", "PY2")
    visibility = kwargs.get("visibility")
    testonly = kwargs.get("testonly", True)
    tags = kwargs.get("tags", [])
    parfile_test(
        compiler = compiler,
        default_python_version = default_python_version,
        imports = imports,
        main = main,
        name = name + ".par",
        src = name,
        testonly = testonly,
        visibility = visibility,
        zip_safe = zip_safe,
        tags = tags,
    )