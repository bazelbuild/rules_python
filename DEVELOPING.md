# For Developers

## Updating internal dependencies

1. Modify the `./python/private/pypi/requirements.txt` file and run:
   ```
   bazel run //private:whl_library_requirements.update
   ```
1. Run the following target to update `twine` dependencies:
   ```
   bazel run //private:requirements.update
   ```
1. Bump the coverage dependencies using the script using:
   ```
   bazel run //tools/private/update_deps:update_coverage_deps <VERSION>
   # for example:
   # bazel run //tools/private/update_deps:update_coverage_deps 7.6.1
   ```

## Updating tool dependencies

It's suggested to routinely update the tool versions within our repo - some of the
tools are using requirement files compiled by `uv` and others use other means. In order
to have everything self-documented, we have a special target -
`//private:requirements.update`, which uses `rules_multirun` to run in sequence all
of the requirement updating scripts in one go. This can be done once per release as
we prepare for releases.
