<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#py_package"></a>

## py_package

<pre>
py_package(<a href="#py_package-name">name</a>, <a href="#py_package-deps">deps</a>, <a href="#py_package-packages">packages</a>)
</pre>

A rule to select all files in transitive dependencies of deps which
belong to given set of Python packages.

This rule is intended to be used as data dependency to py_wheel rule


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_package-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="py_package-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="py_package-packages">
      <td><code>packages</code></td>
      <td>
        List of strings; optional
        <p>
          List of Python packages to include in the distribution.
Sub-packages are automatically included.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#py_wheel"></a>

## py_wheel

<pre>
py_wheel(<a href="#py_wheel-name">name</a>, <a href="#py_wheel-abi">abi</a>, <a href="#py_wheel-author">author</a>, <a href="#py_wheel-author_email">author_email</a>, <a href="#py_wheel-classifiers">classifiers</a>, <a href="#py_wheel-console_scripts">console_scripts</a>, <a href="#py_wheel-deps">deps</a>, <a href="#py_wheel-description_file">description_file</a>, <a href="#py_wheel-distribution">distribution</a>, <a href="#py_wheel-entry_points">entry_points</a>, <a href="#py_wheel-extra_requires">extra_requires</a>, <a href="#py_wheel-homepage">homepage</a>, <a href="#py_wheel-license">license</a>, <a href="#py_wheel-platform">platform</a>, <a href="#py_wheel-python_requires">python_requires</a>, <a href="#py_wheel-python_tag">python_tag</a>, <a href="#py_wheel-requires">requires</a>, <a href="#py_wheel-strip_path_prefixes">strip_path_prefixes</a>, <a href="#py_wheel-version">version</a>)
</pre>


A rule for building Python Wheels.

Wheels are Python distribution format defined in https://www.python.org/dev/peps/pep-0427/.

This rule packages a set of targets into a single wheel.

Currently only pure-python wheels are supported.

Examples:

```python
# Package just a specific py_libraries, without their dependencies
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


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_wheel-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-abi">
      <td><code>abi</code></td>
      <td>
        String; optional
        <p>
          Python ABI tag. 'none' for pure-Python wheels.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-author">
      <td><code>author</code></td>
      <td>
        String; optional
        <p>
          A string specifying the author of the package.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-author_email">
      <td><code>author_email</code></td>
      <td>
        String; optional
        <p>
          A string specifying the email address of the package author.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-classifiers">
      <td><code>classifiers</code></td>
      <td>
        List of strings; optional
        <p>
          A list of strings describing the categories for the package.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-console_scripts">
      <td><code>console_scripts</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
        <p>
          Deprecated console_script entry points, e.g. `{'main': 'examples.wheel.main:main'}`.

Deprecated: prefer the `entry_points` attribute, which supports `console_scripts` as well as other entry points.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          Targets to be included in the distribution.

The targets to package are usually `py_library` rules or filesets (for packaging data files).

Note it's usually better to package `py_library` targets and use
`entry_points` attribute to specify `console_scripts` than to package
`py_binary` rules. `py_binary` targets would wrap a executable script that
tries to locate `.runfiles` directory which is not packaged in the wheel.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-description_file">
      <td><code>description_file</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          A file containing text describing the package in a single line.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-distribution">
      <td><code>distribution</code></td>
      <td>
        String; required
        <p>
          Name of the distribution.

This should match the project name onm PyPI. It's also the name that is used to
refer to the package in other packages' dependencies.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-entry_points">
      <td><code>entry_points</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a>; optional
        <p>
          entry_points, e.g. `{'console_scripts': ['main = examples.wheel.main:main']}`.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-extra_requires">
      <td><code>extra_requires</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a>; optional
        <p>
          List of optional requirements for this package
        </p>
      </td>
    </tr>
    <tr id="py_wheel-homepage">
      <td><code>homepage</code></td>
      <td>
        String; optional
        <p>
          A string specifying the URL for the package homepage.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-license">
      <td><code>license</code></td>
      <td>
        String; optional
        <p>
          A string specifying the license of the package.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-platform">
      <td><code>platform</code></td>
      <td>
        String; optional
        <p>
          Supported platform. Use 'any' for pure-Python wheel.

If you have included platform-specific data, such as a .pyd or .so
extension module, you will need to specify the platform in standard
pip format. If you support multiple platforms, you can define
platform constraints, then use a select() to specify the appropriate
specifier, eg:

<code>
platform = select({
    "//platforms:windows_x86_64": "win_amd64",
    "//platforms:macos_x86_64": "macosx_10_7_x86_64",
    "//platforms:linux_x86_64": "manylinux2014_x86_64",
})
</code>
        </p>
      </td>
    </tr>
    <tr id="py_wheel-python_requires">
      <td><code>python_requires</code></td>
      <td>
        String; optional
        <p>
          A string specifying what other distributions need to be installed when this one is. See the section on [Declaring required dependency](https://setuptools.readthedocs.io/en/latest/userguide/dependency_management.html#declaring-dependencies) for details and examples of the format of this argument.
        </p>
      </td>
    </tr>
    <tr id="py_wheel-python_tag">
      <td><code>python_tag</code></td>
      <td>
        String; optional
        <p>
          Supported Python version(s), eg `py3`, `cp35.cp36`, etc
        </p>
      </td>
    </tr>
    <tr id="py_wheel-requires">
      <td><code>requires</code></td>
      <td>
        List of strings; optional
        <p>
          List of requirements for this package
        </p>
      </td>
    </tr>
    <tr id="py_wheel-strip_path_prefixes">
      <td><code>strip_path_prefixes</code></td>
      <td>
        List of strings; optional
        <p>
          path prefixes to strip from files added to the generated package
        </p>
      </td>
    </tr>
    <tr id="py_wheel-version">
      <td><code>version</code></td>
      <td>
        String; required
        <p>
          Version number of the package
        </p>
      </td>
    </tr>
  </tbody>
</table>


