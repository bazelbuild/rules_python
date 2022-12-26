load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load(":requirements_parser_tests.bzl", parse_requirements_tests = "parse_tests")

diff_test(
    name = "srcs_diff_test",
    failure_message = (
        "Please run 'bazel run //python/pip_install/private:srcs_module.update' " +
        "to update the 'srcs.bzl' module found in the same package."
    ),
    file1 = "//python/pip_install/private:srcs_module",
    file2 = "//python/pip_install/private:srcs.bzl",
    # TODO: The diff_test here fails on Windows. As does the
    # install script. This should be fixed.
    target_compatible_with = select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
)

parse_requirements_tests(name = "test_parse_requirements")
