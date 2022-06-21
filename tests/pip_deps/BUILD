filegroup(
    name = "requirements_txt",
    srcs = ["requirements.txt"],
    visibility = ["//visibility:public"],
)

test_suite(
    name = "external_tests",
    tests = [
        "@unpinned_pip//:pin_test",
    ],
)

sh_test(
    name = "no_external_test",
    srcs = ["test.sh"],
    args = ["$(rootpath :requirements_txt)"],
    data = [":requirements_txt"],
)
