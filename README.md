# rules_python_external

Contains Bazel rules to fetch and install Python dependencies from a requirements.txt file.

## Usage

In `requirements.txt`
```
cryptography==2.8
boto3==1.9.253
```

In `WORKSPACE`

```
rules_python_external_version = "{COMMIT_SHA}"

http_archive(
    name = "rules_python_external",
    sha256 = "", # Fill in with correct sha256 of your COMMIT_SHA version
    strip_prefix = "rules_python_external-{version}".format(version = rules_python_external_version),
    url = "https://github.com/dillon-giacoppo/rules_python_external/archive/{version}.zip".format(version = rules_python_external_version),
)

load("@rules_python_external//:defs.bzl", "pip_repository")

pip_repository(
    name = "py_deps",
    requirements = "//third_party:requirements.txt",
)
```

Example `BUILD` file.

```
load("@py_deps//:requirements.bzl", "requirement")

py_binary(
    name = "main",
    srcs = ["main.py"],
    deps = [
        requirement("boto3"), # or @py_deps//pypi__boto3
    ],
)
```

## Development

### Testing

`bazel test //...`
