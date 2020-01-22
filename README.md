# rules_python_external

Contains Bazel rules to fetch and install Python dependencies from a requirements.txt file.

## Usage

#### Setup `requirements.txt` 

While `rules_python_external` **does not** require a _transitively-closed_ `requirements.txt` file, it is recommended. But if you want to just have top-level packages listed, that works. 

Transitively-closed requirements specs are very tedious to produce and maintain manually. To automate the process we recommend [`pip-compile` from `jazzband/pip-tools`](https://github.com/jazzband/pip-tools#example-usage-for-pip-compile).

For example, `pip-compile` takes a `requirements.in` like this:

```
boto3~=1.9.227
botocore~=1.12.247
click~=7.0
```

These above are the third-party packages you can directly import.

`pip-compile` 'compiles' it so you get a transitively-closed `requirements.txt` like this, which should be passed to `pip_install` below:

```
boto3==1.9.253
botocore==1.12.253
click==7.0
docutils==0.15.2          # via botocore
jmespath==0.9.4           # via boto3, botocore
python-dateutil==2.8.1    # via botocore
s3transfer==0.2.1         # via boto3
six==1.14.0               # via python-dateutil
urllib3==1.25.8           # via botocore
```

#### Setup `WORKSPACE`

```python
rules_python_external_version = "{COMMIT_SHA}"

http_archive(
    name = "rules_python_external",
    sha256 = "", # Fill in with correct sha256 of your COMMIT_SHA version
    strip_prefix = "rules_python_external-{version}".format(version = rules_python_external_version),
    url = "https://github.com/dillon-giacoppo/rules_python_external/archive/{version}.zip".format(version = rules_python_external_version),
)

# Install the rule dependencies
load("@rules_python_external//:repositories.bzl", "rules_python_external_dependencies")
rules_python_external_dependencies()

load("@rules_python_external//:defs.bzl", "pip_install")
pip_install(
    name = "py_deps",
    requirements = "//:requirements.txt",
)
```

Example `BUILD` file.

```python
load("@py_deps//:requirements.bzl", "requirement")

py_binary(
    name = "main",
    srcs = ["main.py"],
    deps = [
        requirement("boto3"), # or @py_deps//pypi__boto3
    ],
)
```

Note that above you do not need to add transitively required packages to `deps = [ ... ]`

## Development

### Testing

`bazel test //...`
