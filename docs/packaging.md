<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#py_package"></a>

## py_package

<pre>
py_package(<a href="#py_package-name">name</a>, <a href="#py_package-deps">deps</a>, <a href="#py_package-packages">packages</a>)
</pre>

A rule to select all files in transitive dependencies of deps which
belong to given set of Python packages.

This rule is intended to be used as data dependency to py_wheel rule


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| packages |  List of Python packages to include in the distribution. Sub-packages are automatically included.   | List of strings | optional | [] |


<a name="#py_wheel"></a>

## py_wheel

<pre>
py_wheel(<a href="#py_wheel-name">name</a>, <a href="#py_wheel-abi">abi</a>, <a href="#py_wheel-author">author</a>, <a href="#py_wheel-author_email">author_email</a>, <a href="#py_wheel-classifiers">classifiers</a>, <a href="#py_wheel-console_scripts">console_scripts</a>, <a href="#py_wheel-deps">deps</a>, <a href="#py_wheel-description_file">description_file</a>,
         <a href="#py_wheel-distribution">distribution</a>, <a href="#py_wheel-entry_points">entry_points</a>, <a href="#py_wheel-extra_requires">extra_requires</a>, <a href="#py_wheel-homepage">homepage</a>, <a href="#py_wheel-license">license</a>, <a href="#py_wheel-platform">platform</a>, <a href="#py_wheel-python_requires">python_requires</a>,
         <a href="#py_wheel-python_tag">python_tag</a>, <a href="#py_wheel-requires">requires</a>, <a href="#py_wheel-stamp">stamp</a>, <a href="#py_wheel-strip_path_prefixes">strip_path_prefixes</a>, <a href="#py_wheel-version">version</a>)
</pre>


A rule for building Python Wheels.

Wheels are Python distribution format defined in https://www.python.org/dev/peps/pep-0427/.

This rule packages a set of targets into a single wheel.

Currently only pure-python wheels are supported.

Examples:

```python
# Package some specific py_library targets, without their dependencies
py_wheel(
    name = "minimal_with_py_library",
    # Package data. We're building "example_minimal_library-0.0.1-py3-none-any.whl"
    distribution = "example_minimal_library",
    python_tag = "py3",
    version = "0.0.1",
    deps = [
        "//examples/wheel/lib:module_with_data",
        "//examples/wheel/lib:simple_module",
    ],
)

# Use py_package to collect all transitive dependencies of a target,
# selecting just the files within a specific python package.
py_package(
    name = "example_pkg",
    # Only include these Python packages.
    packages = ["examples.wheel"],
    deps = [":main"],
)

py_wheel(
    name = "minimal_with_py_package",
    # Package data. We're building "example_minimal_package-0.0.1-py3-none-any.whl"
    distribution = "example_minimal_package",
    python_tag = "py3",
    version = "0.0.1",
    deps = [":example_pkg"],
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| abi |  Python ABI tag. 'none' for pure-Python wheels.   | String | optional | "none" |
| author |  A string specifying the author of the package.   | String | optional | "" |
| author_email |  A string specifying the email address of the package author.   | String | optional | "" |
| classifiers |  A list of strings describing the categories for the package. For valid classifiers see https://pypi.org/classifiers   | List of strings | optional | [] |
| console_scripts |  Deprecated console_script entry points, e.g. <code>{'main': 'examples.wheel.main:main'}</code>.<br><br>Deprecated: prefer the <code>entry_points</code> attribute, which supports <code>console_scripts</code> as well as other entry points.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| deps |  Targets to be included in the distribution.<br><br>The targets to package are usually <code>py_library</code> rules or filesets (for packaging data files).<br><br>Note it's usually better to package <code>py_library</code> targets and use <code>entry_points</code> attribute to specify <code>console_scripts</code> than to package <code>py_binary</code> rules. <code>py_binary</code> targets would wrap a executable script that tries to locate <code>.runfiles</code> directory which is not packaged in the wheel.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| description_file |  A file containing text describing the package in a single line.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| distribution |  Name of the distribution.<br><br>This should match the project name onm PyPI. It's also the name that is used to refer to the package in other packages' dependencies.   | String | required |  |
| entry_points |  entry_points, e.g. <code>{'console_scripts': ['main = examples.wheel.main:main']}</code>.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a> | optional | {} |
| extra_requires |  List of optional requirements for this package   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a> | optional | {} |
| homepage |  A string specifying the URL for the package homepage.   | String | optional | "" |
| license |  A string specifying the license of the package.   | String | optional | "" |
| platform |  Supported platform. Use 'any' for pure-Python wheel.<br><br>If you have included platform-specific data, such as a .pyd or .so extension module, you will need to specify the platform in standard pip format. If you support multiple platforms, you can define platform constraints, then use a select() to specify the appropriate specifier, eg:<br><br><code> platform = select({     "//platforms:windows_x86_64": "win_amd64",     "//platforms:macos_x86_64": "macosx_10_7_x86_64",     "//platforms:linux_x86_64": "manylinux2014_x86_64", }) </code>   | String | optional | "any" |
| python_requires |  A string specifying what other distributions need to be installed when this one is. See the section on [Declaring required dependency](https://setuptools.readthedocs.io/en/latest/userguide/dependency_management.html#declaring-dependencies) for details and examples of the format of this argument.   | String | optional | "" |
| python_tag |  Supported Python version(s), eg <code>py3</code>, <code>cp35.cp36</code>, etc   | String | optional | "py3" |
| requires |  List of requirements for this package   | List of strings | optional | [] |
| stamp |  Whether to encode build information into the wheel. Possible values:<br><br>- <code>stamp = 1</code>: Always stamp the build information into the wheel, even in [--nostamp](https://docs.bazel.build/versions/main/user-manual.html#flag--stamp) builds. This setting should be avoided, since it potentially kills remote caching for the target and any downstream actions that depend on it.<br><br>- <code>stamp = 0</code>: Always replace build information by constant values. This gives good build result caching.<br><br>- <code>stamp = -1</code>: Embedding of build information is controlled by the [--[no]stamp](https://docs.bazel.build/versions/main/user-manual.html#flag--stamp) flag.<br><br>Stamped targets are not rebuilt unless their dependencies change.   | Integer | optional | -1 |
| strip_path_prefixes |  path prefixes to strip from files added to the generated package   | List of strings | optional | [] |
| version |  Version number of the package. Note that this attribute supports stamp format strings. Eg <code>1.2.3-{BUILD_TIMESTAMP}</code>   | String | required |  |


<a name="#PyWheelInfo"></a>

## PyWheelInfo

<pre>
PyWheelInfo(<a href="#PyWheelInfo-name_file">name_file</a>, <a href="#PyWheelInfo-wheel">wheel</a>)
</pre>

Information about a wheel produced by `py_wheel`

**FIELDS**


| Name  | Description |
| :-------------: | :-------------: |
| name_file |  File: A file containing the canonical name of the wheel (after stamping, if enabled).    |
| wheel |  File: The wheel file itself.    |


