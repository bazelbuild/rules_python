# For Developers

## Releasing major versions

Start from a clean checkout at `main`.

Before running through the release it's good to run the build and the tests locally, and make sure CI is passing. You can
also test-drive the commit in an existing Bazel workspace to sanity check functionality.

#### Determining Semantic Version

**rules_python** is currently using [Zero-based versioning](https://0ver.org/) and thus backwards-incompatible API
changes still come under the minor-version digit. So releases with API changes and new features bump the minor, and
those with only bug fixes and other minor changes bump the patch digit.   

#### Steps 
1. Determine what will be the next release, following semver.
1. Create a tag and push, e.g. `git tag 0.5.0 upstream/main && git push upstream --tags`
1. Watch the release automation run on https://github.com/bazelbuild/rules_python/actions

#### After release creation in Github

1. Ping @philwo to get the new release added to mirror.bazel.build. See [this comment on issue #400](https://github.com/bazelbuild/rules_python/issues/400#issuecomment-779159530) for more context.
1. Announce the release in the #python channel in the Bazel slack (bazelbuild.slack.com).

## Patch releases

Patch releases are done similar to regular releases, except a branch is based
from the release tag and changes are done in the patch-main branch. In the docs
below, we assume we're creating the `0.18.1` patch release.

### Steps

1. Create patch branch locally: `git checkout -b main-0.18.1 0.18.0`
2. Push to Github repo: `git push`

From here, the `main-0.18.1` is like any other branch. Usually what you'll
do is `git cherry-pick` specific commits from `main` to the patch's main:

* `git cherry-pick <commit>`

Then push your changes with `git push`.

You can also go through the regular commit and pull request workflow.

When ready, tag the patch-main branch like a regular release; see the regular
releasing steps.

## Secrets

### PyPI user rules-python

Part of the release process uploads packages to PyPI as the user `rules-python`.
This account is managed by Google; contact rules-python-pyi@google.com if
something needs to be done with the PyPI account.
