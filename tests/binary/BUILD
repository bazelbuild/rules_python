load("//python:defs.bzl", "py_binary")

py_binary(
    name = "foo",
    srcs = ["foo.py"],
)

sh_test(
    name = "test",
    srcs = ["test.sh"],
    data = [":foo"],
    args = [
        "$(location :foo)",
    ],
    size = "small",
)
