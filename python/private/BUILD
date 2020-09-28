# Needed to define bzl_library targets for docgen. (We don't define the
# bzl_library target here because it'd give our users a transitive dependency
# on Skylib.)
exports_files(
    ["reexports.bzl"],
    visibility = ["//docs:__pkg__"],
)
