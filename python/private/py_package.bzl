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

"Implementation of py_package rule"

def _path_inside_wheel(input_file):
    # input_file.short_path is sometimes relative ("../${repository_root}/foobar")
    # which is not a valid path within a zip file. Fix that.
    short_path = input_file.short_path
    if short_path.startswith("..") and len(short_path) >= 3:
        # Path separator. '/' on linux.
        separator = short_path[2]

        # Consume '../' part.
        short_path = short_path[3:]

        # Find position of next '/' and consume everything up to that character.
        pos = short_path.find(separator)
        short_path = short_path[pos + 1:]
    return short_path

def _py_package_impl(ctx):
    # TODO: '/' is wrong on windows, but the path separator is not available in starlark.
    # Fix this once ctx.configuration has directory separator information.
    packages = [p.replace(".", "/") for p in ctx.attr.packages]
    exclude = [p.replace(".", "/") for p in ctx.attr.exclude]
    transitive_sources = [
        dep[PyInfo].transitive_sources
        for dep in ctx.attr.deps
    ]

    # TODO(f0rmiga): the logic here is incomplete because symlinks, root_symlinks, and
    # empty_filesnames aren't being accounted for.
    runfiles = [
        dep[DefaultInfo].default_runfiles.files
        for dep in ctx.attr.deps
    ]
    input_files = depset(transitive = transitive_sources + runfiles)
    imports = []
    if not packages and not exclude:
        filtered_inputs = input_files
        imports = [dep[PyInfo].imports for dep in ctx.attr.deps]
    else:
        input_files_list = input_files.to_list()
        filtered_files = []
        for dep in ctx.attr.deps:
            (dep_imports, dep_filtered_files) = _py_package_add_imports(dep, input_files_list, packages, exclude)
            imports.append(dep_imports)
            filtered_files.extend(dep_filtered_files)
        filtered_inputs = depset(direct = filtered_files)

    return [
        DefaultInfo(
            files = filtered_inputs,
        ),
        PyInfo(
            transitive_sources = filtered_inputs,
            imports = depset(transitive = imports),
        ),
    ]

def _py_package_add_imports(dep, input_files, packages, exclude):
    """Returns the imports and filtered files for the given dep based on the packages and exclude list.

    Args:
        dep: Target, the dependency to add imports for.
        input_files: List of input Files.
        packages: List of strings, packages to include.
        exclude: List of strings packages to exclude.
    """
    filtered_files = []
    add_imports = False

    for input_file in input_files:
        path_inside_wheel = _path_inside_wheel(input_file)
        for package in packages:
            if _py_package_should_include_file(path_inside_wheel, package, exclude):
                filtered_files.append(input_file)
                add_imports = add_imports or path_inside_wheel.endswith(".py")

    if add_imports:
        return (dep[PyInfo].imports, filtered_files)

    return ([], filtered_files)

def _py_package_should_include_file(path_inside_wheel, package, exclude):
    """Returns true if the file should be included in the wheel based on the package and exclude list.

    Args:
        path_inside_wheel: Path of the file inside the wheel.
        package: Package name to include.
        exclude: List of packages to exclude.
    """
    return path_inside_wheel.startswith(package) and (not exclude or not path_inside_wheel.startswith(exclude))

py_package_lib = struct(
    implementation = _py_package_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "",
            providers = [PyInfo],
        ),
        "exclude": attr.string_list(
            mandatory = False,
            default = [],
            doc = """\
List of Python packages to exclude from the distribution.
Sub-packages are automatically excluded.
""",
        ),
        "packages": attr.string_list(
            mandatory = False,
            allow_empty = True,
            doc = """\
List of Python packages to include in the distribution.
Sub-packages are automatically included.
""",
        ),
    },
    path_inside_wheel = _path_inside_wheel,
)
