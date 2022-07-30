<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#pip_repository"></a>

## pip_repository

<pre>
pip_repository(<a href="#pip_repository-name">name</a>, <a href="#pip_repository-annotations">annotations</a>, <a href="#pip_repository-download_only">download_only</a>, <a href="#pip_repository-enable_implicit_namespace_pkgs">enable_implicit_namespace_pkgs</a>, <a href="#pip_repository-environment">environment</a>,
               <a href="#pip_repository-extra_pip_args">extra_pip_args</a>, <a href="#pip_repository-incremental">incremental</a>, <a href="#pip_repository-isolated">isolated</a>, <a href="#pip_repository-pip_data_exclude">pip_data_exclude</a>, <a href="#pip_repository-python_interpreter">python_interpreter</a>,
               <a href="#pip_repository-python_interpreter_target">python_interpreter_target</a>, <a href="#pip_repository-quiet">quiet</a>, <a href="#pip_repository-repo_prefix">repo_prefix</a>, <a href="#pip_repository-requirements">requirements</a>, <a href="#pip_repository-requirements_darwin">requirements_darwin</a>,
               <a href="#pip_repository-requirements_linux">requirements_linux</a>, <a href="#pip_repository-requirements_lock">requirements_lock</a>, <a href="#pip_repository-requirements_windows">requirements_windows</a>, <a href="#pip_repository-timeout">timeout</a>)
</pre>

A rule for importing `requirements.txt` dependencies into Bazel.

This rule imports a `requirements.txt` file and generates a new
`requirements.bzl` file.  This is used via the `WORKSPACE` pattern:

```python
pip_repository(
    name = "foo",
    requirements = ":requirements.txt",
)
```

You can then reference imported dependencies from your `BUILD` file with:

```python
load("@foo//:requirements.bzl", "requirement")
py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       requirement("requests"),
       requirement("numpy"),
    ],
)
```

Or alternatively:
```python
load("@foo//:requirements.bzl", "all_requirements")
py_binary(
    name = "baz",
    ...
    deps = [
       ":foo",
    ] + all_requirements,
)
```


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| annotations |  Optional annotations to apply to packages   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| download_only |  Whether to use "pip download" instead of "pip wheel". Disables building wheels from source, but allows use of --platform, --python-version, --implementation, and --abi in --extra_pip_args to download wheels for a different platform from the host platform.   | Boolean | optional | False |
| enable_implicit_namespace_pkgs |  If true, disables conversion of native namespace packages into pkg-util style namespace packages. When set all py_binary and py_test targets must specify either <code>legacy_create_init=False</code> or the global Bazel option <code>--incompatible_default_to_explicit_init_py</code> to prevent <code>__init__.py</code> being automatically generated in every directory.<br><br>This option is required to support some packages which cannot handle the conversion to pkg-util style.   | Boolean | optional | False |
| environment |  Environment variables to set in the pip subprocess. Can be used to set common variables such as <code>http_proxy</code>, <code>https_proxy</code> and <code>no_proxy</code> Note that pip is run with "--isolated" on the CLI so PIP_&lt;VAR&gt;_&lt;NAME&gt; style env vars are ignored, but env vars that control requests and urllib3 can be passed.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| extra_pip_args |  Extra arguments to pass on to pip. Must not contain spaces.   | List of strings | optional | [] |
| incremental |  Create the repository in incremental mode.   | Boolean | optional | False |
| isolated |  Whether or not to pass the [--isolated](https://pip.pypa.io/en/stable/cli/pip/#cmdoption-isolated) flag to the underlying pip command. Alternatively, the <code>RULES_PYTHON_PIP_ISOLATED</code> enviornment varaible can be used to control this flag.   | Boolean | optional | True |
| pip_data_exclude |  Additional data exclusion parameters to add to the pip packages BUILD file.   | List of strings | optional | [] |
| python_interpreter |  The python interpreter to use. This can either be an absolute path or the name of a binary found on the host's <code>PATH</code> environment variable. If no value is set <code>python3</code> is defaulted for Unix systems and <code>python.exe</code> for Windows.   | String | optional | "" |
| python_interpreter_target |  If you are using a custom python interpreter built by another repository rule, use this attribute to specify its BUILD target. This allows pip_repository to invoke pip using the same interpreter as your toolchain. If set, takes precedence over python_interpreter.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| quiet |  If True, suppress printing stdout and stderr output to the terminal.   | Boolean | optional | True |
| repo_prefix |  Prefix for the generated packages. For non-incremental mode the packages will be of the form<br><br>@&lt;name&gt;//&lt;prefix&gt;&lt;sanitized-package-name&gt;/...<br><br>For incremental mode the packages will be of the form<br><br>@&lt;prefix&gt;&lt;sanitized-package-name&gt;//...   | String | optional | "" |
| requirements |  A 'requirements.txt' pip requirements file.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| requirements_darwin |  Override the requirements_lock attribute when the host platform is Mac OS   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| requirements_linux |  Override the requirements_lock attribute when the host platform is Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| requirements_lock |  A fully resolved 'requirements.txt' pip requirement file containing the transitive set of your dependencies. If this file is passed instead of 'requirements' no resolve will take place and pip_repository will create individual repositories for each of your dependencies so that wheels are fetched/built only for the targets specified by 'build/run/test'.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| requirements_windows |  Override the requirements_lock attribute when the host platform is Windows   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| timeout |  Timeout (in seconds) on the rule's execution duration.   | Integer | optional | 600 |


<a name="#whl_library"></a>

## whl_library

<pre>
whl_library(<a href="#whl_library-name">name</a>, <a href="#whl_library-annotation">annotation</a>, <a href="#whl_library-download_only">download_only</a>, <a href="#whl_library-enable_implicit_namespace_pkgs">enable_implicit_namespace_pkgs</a>, <a href="#whl_library-environment">environment</a>,
            <a href="#whl_library-extra_pip_args">extra_pip_args</a>, <a href="#whl_library-isolated">isolated</a>, <a href="#whl_library-pip_data_exclude">pip_data_exclude</a>, <a href="#whl_library-python_interpreter">python_interpreter</a>, <a href="#whl_library-python_interpreter_target">python_interpreter_target</a>,
            <a href="#whl_library-quiet">quiet</a>, <a href="#whl_library-repo">repo</a>, <a href="#whl_library-repo_prefix">repo_prefix</a>, <a href="#whl_library-requirement">requirement</a>, <a href="#whl_library-timeout">timeout</a>)
</pre>


Download and extracts a single wheel based into a bazel repo based on the requirement string passed in.
Instantiated from pip_repository and inherits config options from there.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| annotation |  Optional json encoded file containing annotation to apply to the extracted wheel. See <code>package_annotation</code>   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| download_only |  Whether to use "pip download" instead of "pip wheel". Disables building wheels from source, but allows use of --platform, --python-version, --implementation, and --abi in --extra_pip_args to download wheels for a different platform from the host platform.   | Boolean | optional | False |
| enable_implicit_namespace_pkgs |  If true, disables conversion of native namespace packages into pkg-util style namespace packages. When set all py_binary and py_test targets must specify either <code>legacy_create_init=False</code> or the global Bazel option <code>--incompatible_default_to_explicit_init_py</code> to prevent <code>__init__.py</code> being automatically generated in every directory.<br><br>This option is required to support some packages which cannot handle the conversion to pkg-util style.   | Boolean | optional | False |
| environment |  Environment variables to set in the pip subprocess. Can be used to set common variables such as <code>http_proxy</code>, <code>https_proxy</code> and <code>no_proxy</code> Note that pip is run with "--isolated" on the CLI so PIP_&lt;VAR&gt;_&lt;NAME&gt; style env vars are ignored, but env vars that control requests and urllib3 can be passed.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| extra_pip_args |  Extra arguments to pass on to pip. Must not contain spaces.   | List of strings | optional | [] |
| isolated |  Whether or not to pass the [--isolated](https://pip.pypa.io/en/stable/cli/pip/#cmdoption-isolated) flag to the underlying pip command. Alternatively, the <code>RULES_PYTHON_PIP_ISOLATED</code> enviornment varaible can be used to control this flag.   | Boolean | optional | True |
| pip_data_exclude |  Additional data exclusion parameters to add to the pip packages BUILD file.   | List of strings | optional | [] |
| python_interpreter |  The python interpreter to use. This can either be an absolute path or the name of a binary found on the host's <code>PATH</code> environment variable. If no value is set <code>python3</code> is defaulted for Unix systems and <code>python.exe</code> for Windows.   | String | optional | "" |
| python_interpreter_target |  If you are using a custom python interpreter built by another repository rule, use this attribute to specify its BUILD target. This allows pip_repository to invoke pip using the same interpreter as your toolchain. If set, takes precedence over python_interpreter.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| quiet |  If True, suppress printing stdout and stderr output to the terminal.   | Boolean | optional | True |
| repo |  Pointer to parent repo name. Used to make these rules rerun if the parent repo changes.   | String | required |  |
| repo_prefix |  Prefix for the generated packages. For non-incremental mode the packages will be of the form<br><br>@&lt;name&gt;//&lt;prefix&gt;&lt;sanitized-package-name&gt;/...<br><br>For incremental mode the packages will be of the form<br><br>@&lt;prefix&gt;&lt;sanitized-package-name&gt;//...   | String | optional | "" |
| requirement |  Python requirement string describing the package to make available   | String | required |  |
| timeout |  Timeout (in seconds) on the rule's execution duration.   | Integer | optional | 600 |


<a name="#package_annotation"></a>

## package_annotation

<pre>
package_annotation(<a href="#package_annotation-additive_build_content">additive_build_content</a>, <a href="#package_annotation-copy_files">copy_files</a>, <a href="#package_annotation-copy_executables">copy_executables</a>, <a href="#package_annotation-data">data</a>, <a href="#package_annotation-data_exclude_glob">data_exclude_glob</a>,
                   <a href="#package_annotation-srcs_exclude_glob">srcs_exclude_glob</a>)
</pre>

Annotations to apply to the BUILD file content from package generated from a `pip_repository` rule.

[cf]: https://github.com/bazelbuild/bazel-skylib/blob/main/docs/copy_file_doc.md


**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| additive_build_content |  Raw text to add to the generated <code>BUILD</code> file of a package.   |  <code>None</code> |
| copy_files |  A mapping of <code>src</code> and <code>out</code> files for [@bazel_skylib//rules:copy_file.bzl][cf]   |  <code>{}</code> |
| copy_executables |  A mapping of <code>src</code> and <code>out</code> files for     [@bazel_skylib//rules:copy_file.bzl][cf]. Targets generated here will also be flagged as     executable.   |  <code>{}</code> |
| data |  A list of labels to add as <code>data</code> dependencies to the generated <code>py_library</code> target.   |  <code>[]</code> |
| data_exclude_glob |  A list of exclude glob patterns to add as <code>data</code> to the generated     <code>py_library</code> target.   |  <code>[]</code> |
| srcs_exclude_glob |  A list of labels to add as <code>srcs</code> to the generated <code>py_library</code> target.   |  <code>[]</code> |


