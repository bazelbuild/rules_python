def sanitise_name(name: str, prefix: str) -> str:
    """Sanitises the name to be compatible with Bazel labels.

    There are certain requirements around Bazel labels that we need to consider. From the Bazel docs:

        Package names must be composed entirely of characters drawn from the set A-Z, a–z, 0–9, '/', '-', '.', and '_',
        and cannot start with a slash.

    Due to restrictions on Bazel labels we also cannot allow hyphens. See
    https://github.com/bazelbuild/bazel/issues/6841

    Further, rules-python automatically adds the repository root to the PYTHONPATH, meaning a package that has the same
    name as a module is picked up. We workaround this by prefixing with `pypi__`. Alternatively we could require
    `--noexperimental_python_import_all_repositories` be set, however this breaks rules_docker.
    See: https://github.com/bazelbuild/bazel/issues/2636
    """

    return prefix + name.replace("-", "_").replace(".", "_").lower()
