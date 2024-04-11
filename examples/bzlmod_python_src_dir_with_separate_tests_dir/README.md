# Using a `src` dir and separate `tests` dir, with bzlmod

This example highlights how to set up `MODULE.bazel`, `BUILD.bazel`, and `gazelle` to work with
a python `src` directory and a separate `tests` directory[^1].


Run tests by first `cd`ing into this directory and then running `bazel test`:

```shell
$ cd examples/bzlmod_python_src_dir_with_separate_tests_dir
$ bazel test --test_output=errors //...
```

Everything should pass.

Try changing `tests/test_my_python_module.py`'s assert to a different value and run
`bazel test` again. You'll see a test failure, yay!


[^1]: This is how the [Python Packaging User Guide][pypa-tutorial] recommends new python libraries
be set up.

[pypa-tutorial]: https://github.com/pypa/packaging.python.org/blob/091e45c8f78614307ccfdc061a6e562d669b178b/source/tutorials/packaging-projects.rst


## Details

The folder structure, prior to adding Bazel, is:

```
./
├── pyproject.toml
├── README.md
├── src/
│   └── my_package/
│       ├── __init__.py
│       └── my_python_module.py
└── tests/
    ├── __init__.py
    └── test_my_python_module.py
```

After adding files and configuration for Bazel and gazelle:

```
packaging_tutorial/
├── BUILD.bazel             # New
├── gazelle_python.yaml     # New, empty
├── MODULE.bazel            # New
├── pyproject.toml
├── README.md
├── requirements.lock       # New, empty
├── src/
│   ├── BUILD.bazel         # New
│   └── mypackage/
│       ├── __init__.py
│       └── my_python_module.py
└── tests/
    ├── __init__.py
    └── test_my_python_module.py
```

After running Gazelle:

```shell
$ bazel run //:requirements.update
$ bazel run //:gazelle_python_manifest.update
$ bazel run //:gazelle
```

```
packaging_tutorial/
├── BUILD.bazel
├── gazelle_python.yaml     # Updated by 'bazel run //:gazelle_python_manifest.update'
├── MODULE.bazel
├── MODULE.bazel.lock       # New, not included in git repo
├── pyproject.toml
├── README.md
├── requirements.lock       # Updated by 'bazel run //:requirements.update'
├── src/
│   ├── BUILD.bazel
│   └── mypackage/
│       ├── __init__.py
│       ├── BUILD.bazel     # New
│       └── my_python_module.py
└── tests/
    ├── __init__.py
    ├── BUILD.bazel         # New
    └── test_my_python_module.py
```
