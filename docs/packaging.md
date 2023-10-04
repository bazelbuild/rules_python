<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for for building wheels.

<a id="py_package"></a>

## py_package

<pre>
py_package(<a href="#py_package-name">name</a>, <a href="#py_package-deps">deps</a>, <a href="#py_package-packages">packages</a>)
</pre>

A rule to select all files in transitive dependencies of deps which
belong to given set of Python packages.

This rule is intended to be used as data dependency to py_wheel rule.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_package-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_package-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="py_package-packages"></a>packages |  List of Python packages to include in the distribution. Sub-packages are automatically included.   | List of strings | optional | <code>[]</code> |


<a id="py_wheel_dist"></a>

## py_wheel_dist

<pre>
py_wheel_dist(<a href="#py_wheel_dist-name">name</a>, <a href="#py_wheel_dist-out">out</a>, <a href="#py_wheel_dist-wheel">wheel</a>)
</pre>

Prepare a dist/ folder, following Python's packaging standard practice.

See https://packaging.python.org/en/latest/tutorials/packaging-projects/#generating-distribution-archives
which recommends a dist/ folder containing the wheel file(s), source distributions, etc.

This also has the advantage that stamping information is included in the wheel's filename.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_wheel_dist-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_wheel_dist-out"></a>out |  name of the resulting directory   | String | required |  |
| <a id="py_wheel_dist-wheel"></a>wheel |  a [py_wheel rule](/docs/packaging.md#py_wheel_rule)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |


<a id="py_wheel_rule"></a>

## py_wheel_rule

<pre>
py_wheel_rule(<a href="#py_wheel_rule-name">name</a>, <a href="#py_wheel_rule-abi">abi</a>, <a href="#py_wheel_rule-author">author</a>, <a href="#py_wheel_rule-author_email">author_email</a>, <a href="#py_wheel_rule-classifiers">classifiers</a>, <a href="#py_wheel_rule-console_scripts">console_scripts</a>, <a href="#py_wheel_rule-deps">deps</a>,
              <a href="#py_wheel_rule-description_content_type">description_content_type</a>, <a href="#py_wheel_rule-description_file">description_file</a>, <a href="#py_wheel_rule-distribution">distribution</a>, <a href="#py_wheel_rule-entry_points">entry_points</a>,
              <a href="#py_wheel_rule-extra_distinfo_files">extra_distinfo_files</a>, <a href="#py_wheel_rule-extra_requires">extra_requires</a>, <a href="#py_wheel_rule-homepage">homepage</a>, <a href="#py_wheel_rule-incompatible_normalize_name">incompatible_normalize_name</a>,
              <a href="#py_wheel_rule-incompatible_normalize_version">incompatible_normalize_version</a>, <a href="#py_wheel_rule-license">license</a>, <a href="#py_wheel_rule-platform">platform</a>, <a href="#py_wheel_rule-project_urls">project_urls</a>, <a href="#py_wheel_rule-python_requires">python_requires</a>,
              <a href="#py_wheel_rule-python_tag">python_tag</a>, <a href="#py_wheel_rule-requires">requires</a>, <a href="#py_wheel_rule-stamp">stamp</a>, <a href="#py_wheel_rule-strip_path_prefixes">strip_path_prefixes</a>, <a href="#py_wheel_rule-summary">summary</a>, <a href="#py_wheel_rule-version">version</a>)
</pre>

Internal rule used by the [py_wheel macro](/docs/packaging.md#py_wheel).

These intentionally have the same name to avoid sharp edges with Bazel macros.
For example, a `bazel query` for a user's `py_wheel` macro expands to `py_wheel` targets,
in the way they expect.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_wheel_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_wheel_rule-abi"></a>abi |  Python ABI tag. 'none' for pure-Python wheels.   | String | optional | <code>"none"</code> |
| <a id="py_wheel_rule-author"></a>author |  A string specifying the author of the package.   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-author_email"></a>author_email |  A string specifying the email address of the package author.   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-classifiers"></a>classifiers |  A list of strings describing the categories for the package. For valid classifiers see https://pypi.org/classifiers   | List of strings | optional | <code>[]</code> |
| <a id="py_wheel_rule-console_scripts"></a>console_scripts |  Deprecated console_script entry points, e.g. <code>{'main': 'examples.wheel.main:main'}</code>.<br><br>Deprecated: prefer the <code>entry_points</code> attribute, which supports <code>console_scripts</code> as well as other entry points.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="py_wheel_rule-deps"></a>deps |  Targets to be included in the distribution.<br><br>The targets to package are usually <code>py_library</code> rules or filesets (for packaging data files).<br><br>Note it's usually better to package <code>py_library</code> targets and use <code>entry_points</code> attribute to specify <code>console_scripts</code> than to package <code>py_binary</code> rules. <code>py_binary</code> targets would wrap a executable script that tries to locate <code>.runfiles</code> directory which is not packaged in the wheel.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="py_wheel_rule-description_content_type"></a>description_content_type |  The type of contents in description_file. If not provided, the type will be inferred from the extension of description_file. Also see https://packaging.python.org/en/latest/specifications/core-metadata/#description-content-type   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-description_file"></a>description_file |  A file containing text describing the package.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="py_wheel_rule-distribution"></a>distribution |  Name of the distribution.<br><br>This should match the project name onm PyPI. It's also the name that is used to refer to the package in other packages' dependencies.<br><br>Workspace status keys are expanded using <code>{NAME}</code> format, for example:  - <code>distribution = "package.{CLASSIFIER}"</code>  - <code>distribution = "{DISTRIBUTION}"</code><br><br>For the available keys, see https://bazel.build/docs/user-manual#workspace-status   | String | required |  |
| <a id="py_wheel_rule-entry_points"></a>entry_points |  entry_points, e.g. <code>{'console_scripts': ['main = examples.wheel.main:main']}</code>.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional | <code>{}</code> |
| <a id="py_wheel_rule-extra_distinfo_files"></a>extra_distinfo_files |  Extra files to add to distinfo directory in the archive.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | optional | <code>{}</code> |
| <a id="py_wheel_rule-extra_requires"></a>extra_requires |  List of optional requirements for this package   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional | <code>{}</code> |
| <a id="py_wheel_rule-homepage"></a>homepage |  A string specifying the URL for the package homepage.   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-incompatible_normalize_name"></a>incompatible_normalize_name |  Normalize the package distribution name according to latest Python packaging standards.<br><br>See https://packaging.python.org/en/latest/specifications/binary-distribution-format/#escaping-and-unicode and https://packaging.python.org/en/latest/specifications/name-normalization/.<br><br>Apart from the valid names according to the above, we also accept '{' and '}', which may be used as placeholders for stamping.   | Boolean | optional | <code>False</code> |
| <a id="py_wheel_rule-incompatible_normalize_version"></a>incompatible_normalize_version |  Normalize the package version according to PEP440 standard. With this option set to True, if the user wants to pass any stamp variables, they have to be enclosed in '{}', e.g. '{BUILD_TIMESTAMP}'.   | Boolean | optional | <code>False</code> |
| <a id="py_wheel_rule-license"></a>license |  A string specifying the license of the package.   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-platform"></a>platform |  Supported platform. Use 'any' for pure-Python wheel.<br><br>If you have included platform-specific data, such as a .pyd or .so extension module, you will need to specify the platform in standard pip format. If you support multiple platforms, you can define platform constraints, then use a select() to specify the appropriate specifier, eg:<br><br><code> platform = select({     "//platforms:windows_x86_64": "win_amd64",     "//platforms:macos_x86_64": "macosx_10_7_x86_64",     "//platforms:linux_x86_64": "manylinux2014_x86_64", }) </code>   | String | optional | <code>"any"</code> |
| <a id="py_wheel_rule-project_urls"></a>project_urls |  A string dict specifying additional browsable URLs for the project and corresponding labels, where label is the key and url is the value. e.g <code>{{"Bug Tracker": "http://bitbucket.org/tarek/distribute/issues/"}}</code>   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional | <code>{}</code> |
| <a id="py_wheel_rule-python_requires"></a>python_requires |  Python versions required by this distribution, e.g. '&gt;=3.5,&lt;3.7'   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-python_tag"></a>python_tag |  Supported Python version(s), eg <code>py3</code>, <code>cp35.cp36</code>, etc   | String | optional | <code>"py3"</code> |
| <a id="py_wheel_rule-requires"></a>requires |  List of requirements for this package. See the section on [Declaring required dependency](https://setuptools.readthedocs.io/en/latest/userguide/dependency_management.html#declaring-dependencies) for details and examples of the format of this argument.   | List of strings | optional | <code>[]</code> |
| <a id="py_wheel_rule-stamp"></a>stamp |  Whether to encode build information into the wheel. Possible values:<br><br>- <code>stamp = 1</code>: Always stamp the build information into the wheel, even in [--nostamp](https://docs.bazel.build/versions/main/user-manual.html#flag--stamp) builds. This setting should be avoided, since it potentially kills remote caching for the target and any downstream actions that depend on it.<br><br>- <code>stamp = 0</code>: Always replace build information by constant values. This gives good build result caching.<br><br>- <code>stamp = -1</code>: Embedding of build information is controlled by the [--[no]stamp](https://docs.bazel.build/versions/main/user-manual.html#flag--stamp) flag.<br><br>Stamped targets are not rebuilt unless their dependencies change.   | Integer | optional | <code>-1</code> |
| <a id="py_wheel_rule-strip_path_prefixes"></a>strip_path_prefixes |  path prefixes to strip from files added to the generated package   | List of strings | optional | <code>[]</code> |
| <a id="py_wheel_rule-summary"></a>summary |  A one-line summary of what the distribution does   | String | optional | <code>""</code> |
| <a id="py_wheel_rule-version"></a>version |  Version number of the package.<br><br>Note that this attribute supports stamp format strings as well as 'make variables'. For example:   - <code>version = "1.2.3-{BUILD_TIMESTAMP}"</code>   - <code>version = "{BUILD_EMBED_LABEL}"</code>   - <code>version = "$(VERSION)"</code><br><br>Note that Bazel's output filename cannot include the stamp information, as outputs must be known during the analysis phase and the stamp data is available only during the action execution.<br><br>The [<code>py_wheel</code>](/docs/packaging.md#py_wheel) macro produces a <code>.dist</code>-suffix target which creates a <code>dist/</code> folder containing the wheel with the stamped name, suitable for publishing.<br><br>See [<code>py_wheel_dist</code>](/docs/packaging.md#py_wheel_dist) for more info.   | String | required |  |


<a id="PyWheelInfo"></a>

## PyWheelInfo

<pre>
PyWheelInfo(<a href="#PyWheelInfo-name_file">name_file</a>, <a href="#PyWheelInfo-wheel">wheel</a>)
</pre>

Information about a wheel produced by `py_wheel`

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="PyWheelInfo-name_file"></a>name_file |  File: A file containing the canonical name of the wheel (after stamping, if enabled).    |
| <a id="PyWheelInfo-wheel"></a>wheel |  File: The wheel file itself.    |


<a id="py_wheel"></a>

## py_wheel

<pre>
py_wheel(<a href="#py_wheel-name">name</a>, <a href="#py_wheel-twine">twine</a>, <a href="#py_wheel-publish_args">publish_args</a>, <a href="#py_wheel-kwargs">kwargs</a>)
</pre>

Builds a Python Wheel.

Wheels are Python distribution format defined in https://www.python.org/dev/peps/pep-0427/.

This macro packages a set of targets into a single wheel.
It wraps the [py_wheel rule](#py_wheel_rule).

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

To publish the wheel to Pypi, the twine package is required.
rules_python doesn't provide twine itself, see https://github.com/bazelbuild/rules_python/issues/1016
However you can install it with pip_parse, just like we do in the WORKSPACE file in rules_python.

Once you've installed twine, you can pass its label to the `twine` attribute of this macro,
to get a "[name].publish" target.

Example:

```python
py_wheel(
    name = "my_wheel",
    twine = "@publish_deps_twine//:pkg",
    ...
)
```

Now you can run a command like the following, which publishes to https://test.pypi.org/

```sh
% TWINE_USERNAME=__token__ TWINE_PASSWORD=pypi-*** \
    bazel run --stamp --embed_label=1.2.4 -- \
    //path/to:my_wheel.publish --repository testpypi
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_wheel-name"></a>name |  A unique name for this target.   |  none |
| <a id="py_wheel-twine"></a>twine |  A label of the external location of the py_library target for twine   |  <code>None</code> |
| <a id="py_wheel-publish_args"></a>publish_args |  arguments passed to twine, e.g. ["--repository-url", "https://pypi.my.org/simple/"]. These are subject to make var expansion, as with the <code>args</code> attribute. Note that you can also pass additional args to the bazel run command as in the example above.   |  <code>[]</code> |
| <a id="py_wheel-kwargs"></a>kwargs |  other named parameters passed to the underlying [py_wheel rule](#py_wheel_rule)   |  none |


