# With third-party requirements

This test case asserts that a `py_library` is generated with dependencies
extracted from its sources and a `py_binary` is generated embeding the
`py_library` and inherits its dependencies, without specifying the `deps` again.
