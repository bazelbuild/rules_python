# For Developers

## Releasing

Start from a clean checkout at `master`.

Before running through the release it's good to run the build and the tests locally, and make sure CI is passing. You can
also test-drive the commit in an existing Bazel workspace to sanity check functionality.

#### Determining Semantic Version

**rules_python** is currently using [Zero-based versioning](https://0ver.org/) and thus backwards-incompatible API
changes still come under the minor-version digit. So releases with API changes and new features bump the minor, and
those with only bug fixes and other minor changes bump the patch digit.   

#### Steps 

1. Update `version.bzl` with the new semantic version `X.Y.Z`.
2. Run `bazel build //distro:rules_python-X.Y.Z` to build the distributed tarball.
3. Calculate the Sha256 hash of the tarball. This hash will be used in the `http_archive` rules that download the new release.
    1. Example command for OSX: `shasum --algorithm 256 bazel-bin/distro/rules_python-0.1.0.tar.gz`
4. Update nested examples in `examples/*/WORKSPACE` to get the new semantic version with the new `sha256` hash.
5. Create commit called "Release X.Y.Z"
    1. ["release 0.1.0"](https://github.com/bazelbuild/rules_python/commit/c8c79aae9aa1b61d199ad03d5fe06338febd0774) is an example commit.
6. Tag that commit as `X.Y.Z`. Eg. `git tag X.Y.Z`
7. Push the commit and the new tag to `master`.
8. Run `bazel build //distro:relnotes` from within workspace and then from repo root run `cat bazel-bin/distro/relnotes.txt` to get the 'install instructions' that are added as release notes.
    1. Check the `sha256` value matches the one you calculated earlier.
9. ["Draft a new release"](https://github.com/bazelbuild/rules_python/releases/new) in Github (manual for now), selecting the recently pushed `X.Y.Z` tag.
Upload the release artifact from `rules_python-[version].tar.gz`. Also copy the `relnotes.txt` from step 8, adding anything extra if desired.
    
#### After release creation in Github

1. Update `README.md` to point at new release.
2. Ping @philwo to get the new release added to mirror.bazel.build. See [this comment on issue #400](https://github.com/bazelbuild/rules_python/issues/400#issuecomment-779159530) for more context.
3. Announce the release in the #python channel in the Bazel slack (bazelbuild.slack.com). 