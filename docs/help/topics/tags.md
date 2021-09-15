# Tags

The `tags` attribute can appear on any rule, and can have arbitrary values. Some
tags have a special meaning to Bazel, and are listed below.

Tags on test and test_suite rules are useful for categorizing the tests. Tags on
non-test targets are used to control sandboxed execution of genrules and
Starlark actions, and for parsing by humans and/or external tools.

## Tags on test targets

Tags on tests are generally used to annotate a test's role in your debug and
release process. Typically, tags are most useful for C++ and Python tests, which
lack any runtime annotation ability. The use of tags and size elements gives
flexibility in assembling suites of tests based around codebase check-in policy.

Bazel modifies test running behavior if it finds the following keywords in the
tags attribute of the test rule:

| Tag       | Description                                                         |
| --------- | ------------------------------------------------------------------- |
| exclusive | run no other test at the same time                                  |
| external  | test has an external dependency; disable test caching               |
| manual    | don't include test target in wildcard target patterns               |
| large     | test_suite convention; suite of large tests                         |
| medium    | test_suite convention; suite of medium tests                        |
| small     | test_suite convention; suite of small tests                         |
| smoke     | test_suite convention; run these before committing changes into VCS |

Notes:

The `exclusive` tag will force the test to be run in the "exclusive" mode,
ensuring that no other tests are running at the same time. Such tests will be
executed in serial fashion after all build activity and non-exclusive tests have
been completed. Remote execution is disabled for such tests because Bazel
doesn't have control over what's running on a remote machine.

The `external` tag will force the test to be unconditionally executed,
regardless of the value of `--cache_test_results`.

The `manual` tag will exclude the target from expansion of target pattern
wildcards (`...`, `:\*`, `:all`, etc.) and `test_suite` rules which do not list
the test explicitly when computing the set of top-level targets to build/run for
the build, test, and coverage commands. It does not affect target wildcard or
test suite expansion in other contexts, including the query command. Note that
manual does not imply that a target should not be built/run automatically by
continuous build/test systems. For example, it may be desirable to exclude a
target from `bazel test ...` because it requires specific Bazel flags, but still
have it included in properly-configured presubmit or continuous test runs.

## Tags on non-test targets

Bazel modifies the behavior of its sandboxing code if it finds the following
keywords in the tags attribute of any test or genrule target, or the keys of
execution_requirements for any Starlark action.

| Tag               | Description                                                                     |
| ----------------- | ------------------------------------------------------------------------------- |
| no-sandbox        | The action or test will never be run sandboxed.                                 |
|                   | It can still be cached or run remotely;                                         |
|                   | use no-cache or no-remote to prevent either or both of those.                   |
| no-cache          | The action or test result will never be cached, either remotely or locally.     |
| no-remote-cache   | The action or test result will never be cached remotely,                        |
|                   | but it may be cached locally; it may also be executed remotely. [^1]            |
| no-remote-exec    | The action or test will never be executed remotely, but may be cached remotely. |
| no-remote         | Prevents the action or test from being executed remotely or cached remotely.    |
|                   | This is equivalent to using both `no-remote-cache` and `no-remote-exec`.        |
| local             | Prevents the action or test from being remotely cached, remotely executed,      |
|                   | or run inside the sandbox. For genrules and tests, marking the rule             |
|                   | with the `local = True` attribute has the same effect.                          |
| requires-network  | Allows access to the external network from inside the sandbox.                  |
|                   | This tag only has an effect if sandboxing is enabled.                           |
| block-network     | Blocks access to the external network from inside the sandbox.                  |
|                   | In this case, only communication with localhost is allowed.                     |
|                   | This tag only has an effect if sandboxing is enabled.                           |
| requires-fakeroot | runs the test or action as uid and gid 0 (i.e., the root user).                 |
|                   | This is only supported on Linux. This tag takes precedence over the             |
|                   | `--sandbox_fake_username` command-line option.                                  |

[^1] Note: for the purposes of this tag, the disk-cache is considered a local
cache, whereas the http and gRPC caches are considered remote. If a combined
cache is specified (i.e. a cache with local and remote components), it's treated
as a remote cache and disabled entirely unless
`--incompatible_remote_results_ignore_disk` is set, in which case the local
components will be used.

See
https://docs.bazel.build/versions/main/be/common-definitions.html#common-attributes
and
https://docs.bazel.build/versions/main/test-encyclopedia.html#tag-conventions
for the upstream source of this doc.
