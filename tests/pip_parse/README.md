# pip_parse integration tests

This directory contains tests for both, the `pip_parse` repository rules and
the extensions in order to ensure that the resultant contents of the
`@<name>//:requirements.bzl` work as intended.

For now we only try to build the targets that we can access via the macros or
the label lists.
