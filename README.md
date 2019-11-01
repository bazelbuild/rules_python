# rules_python_external

Contains Bazel rules to fetch and install Python dependencies from a requirements.txt file.

## Usage

In `requirements.txt`
```
cryptography[test, docs]
boto3
```

In `WORKSPACE`
```
load("@rules_pip//:defs.bzl", "pip_repository")

pip_repository(
    name = "py_deps",
    requirements = "//:requirements.txt",
)
```

In `BUILD`
```
load("@py_deps//:requirements.bzl", "requirement")

py_binary(
    name = "main",
    srcs = ["main.py"],
    deps = [
        requirement("boto3"),
    ],
)
```
