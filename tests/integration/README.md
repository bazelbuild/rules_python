# Bazel-in-Bazel integration tests

The tests in this directory are Bazel-in-Bazel integration tests. These are
necessary because our CI has a limit of 80 jobs, and our test matrix uses most
of those for more important end-to-end tests of user-facing examples.

The tests in here are more for testing internal aspects of the rules that aren't
easily tested as tests run by Bazel itself (basically anything that happens
prior to the analysis phase).
