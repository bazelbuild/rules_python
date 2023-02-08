# For Developers

## Releasing

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

## Secrets

### PyPI user rules-python

Part of the release process uploads packages to PyPI as the user `rules-python`.
This account is managed by Google; contact rules-python-pyi@google.com if
something needs to be done with the PyPI account.
