# Releasing

Start from a clean checkout at `main`.

Before running through the release it's good to run the build and the tests locally, and make sure CI is passing. You can
also test-drive the commit in an existing Bazel workspace to sanity check functionality.

## Releasing from HEAD

### Steps
1. [Determine the next semantic version number](#determining-semantic-version).
1. Update CHANGELOG.md: replace the `v0-0-0` and `0.0.0` with `X.Y.0`.
1. Replace `VERSION_NEXT_*` strings with `X.Y.0`.
1. Send these changes for review and get them merged.
1. Create a branch for the new release, named `release/X.Y`
   ```
   git branch --no-track release/X.Y upstream/main && git push upstream release/X.Y
   ```
1. Create a tag and push:
   ```
   git tag X.Y.0 upstream/release/X.Y && git push upstream --tags
   ```
   **NOTE:** Pushing the tag will trigger release automation.
1. Release automation will create a GitHub release and BCR pull request.

### Determining Semantic Version

**rules_python** uses [semantic version](https://semver.org), so releases with
API changes and new features bump the minor, and those with only bug fixes and
other minor changes bump the patch digit.

To find if there were any features added or incompatible changes made, review
[CHANGELOG.md](CHANGELOG.md) and the commit history. This can be done using
github by going to the url:
`https://github.com/bazelbuild/rules_python/compare/<VERSION>...main`.

## Patch release with cherry picks

If a patch release from head would contain changes that aren't appropriate for
a patch release, then the patch release needs to be based on the original
release tag and the patch changes cherry-picked into it.

In this example, release `0.37.0` is being patched to create release `0.37.1`.
The fix being included is commit `deadbeef`.

1. `git checkout release/0.37`
1. `git cherry-pick -x deadbeef`
1. Fix merge conflicts, if any.
1. `git cherry-pick --continue` (if applicable)
1. `git push upstream`

If multiple commits need to be applied, repeat the `git cherry-pick` step for
each.

Once the release branch is in the desired state, use `git tag` to tag it, as
done with a release from head. Release automation will do the rest.

### After release creation in Github

1. Announce the release in the #python channel in the Bazel slack (bazelbuild.slack.com).

## Secrets

### PyPI user rules-python

Part of the release process uploads packages to PyPI as the user `rules-python`.
This account is managed by Google; contact rules-python-pyi@google.com if
something needs to be done with the PyPI account.
