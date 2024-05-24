# This is a "stage 2" bootstrap. We can assume we've running under the desired
# interpreter, with some of the basic interpreter options/envvars set.
# However, more setup is required to make the app's real main file runnable.

import sys

# The Python interpreter unconditionally prepends the directory containing this
# script (following symlinks) to the import path. This is the cause of #9239,
# and is a special case of #7091. We therefore explicitly delete that entry.
# TODO(#7091): Remove this hack when no longer necessary.
# TODO: Use sys.flags.safe_path to determine whether this removal should be
# performed
del sys.path[0]

import contextlib
import os
import re
import runpy
import subprocess
import uuid

# ===== Template substitutions start =====
# We just put them in one place so its easy to tell which are used.

# Runfiles-relative path to the main Python source file.
MAIN = "%main%"
# Colon-delimited string of runfiles-relative import paths to add
IMPORTS_STR = "%imports%"
WORKSPACE_NAME = "%workspace_name%"
# Though the import all value is the correct literal, we quote it
# so this file is parsable by tools.
IMPORT_ALL = True if "%import_all%" == "True" else False
# Runfiles-relative path to the coverage tool entry point, if any.
COVERAGE_TOOL = "%coverage_tool%"

# ===== Template substitutions end =====


# Return True if running on Windows
def is_windows():
    return os.name == "nt"


def get_windows_path_with_unc_prefix(path):
    path = path.strip()

    # No need to add prefix for non-Windows platforms.
    if not is_windows() or sys.version_info[0] < 3:
        return path

    # Starting in Windows 10, version 1607(OS build 14393), MAX_PATH limitations have been
    # removed from common Win32 file and directory functions.
    # Related doc: https://docs.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=cmd#enable-long-paths-in-windows-10-version-1607-and-later
    import platform

    if platform.win32_ver()[1] >= "10.0.14393":
        return path

    # import sysconfig only now to maintain python 2.6 compatibility
    import sysconfig

    if sysconfig.get_platform() == "mingw":
        return path

    # Lets start the unicode fun
    if path.startswith(unicode_prefix):
        return path

    # os.path.abspath returns a normalized absolute path
    return unicode_prefix + os.path.abspath(path)


def search_path(name):
    """Finds a file in a given search path."""
    search_path = os.getenv("PATH", os.defpath).split(os.pathsep)
    for directory in search_path:
        if directory:
            path = os.path.join(directory, name)
            if os.path.isfile(path) and os.access(path, os.X_OK):
                return path
    return None


def is_verbose():
    return bool(os.environ.get("RULES_PYTHON_BOOTSTRAP_VERBOSE"))


def print_verbose(*args, mapping=None, values=None):
    if is_verbose():
        if mapping is not None:
            for key, value in sorted((mapping or {}).items()):
                print(
                    "bootstrap: stage 2:",
                    *args,
                    f"{key}={value!r}",
                    file=sys.stderr,
                    flush=True,
                )
        elif values is not None:
            for i, v in enumerate(values):
                print(
                    "bootstrap: stage 2:",
                    *args,
                    f"[{i}] {v!r}",
                    file=sys.stderr,
                    flush=True,
                )
        else:
            print("bootstrap: stage 2:", *args, file=sys.stderr, flush=True)


def print_verbose_coverage(*args):
    """Print output if VERBOSE_COVERAGE is non-empty in the environment."""
    if os.environ.get("VERBOSE_COVERAGE"):
        print(*args, file=sys.stderr, flush=True)


def is_verbose_coverage():
    """Returns True if VERBOSE_COVERAGE is non-empty in the environment."""
    return os.environ.get("VERBOSE_COVERAGE") or is_verbose()


def find_coverage_entry_point(module_space):
    cov_tool = COVERAGE_TOOL
    if cov_tool:
        print_verbose_coverage("Using toolchain coverage_tool %r" % cov_tool)
    else:
        cov_tool = os.environ.get("PYTHON_COVERAGE")
        if cov_tool:
            print_verbose_coverage("PYTHON_COVERAGE: %r" % cov_tool)
    if cov_tool:
        return find_binary(module_space, cov_tool)
    return None


def find_binary(module_space, bin_name):
    """Finds the real binary if it's not a normal absolute path."""
    if not bin_name:
        return None
    if bin_name.startswith("//"):
        # Case 1: Path is a label. Not supported yet.
        raise AssertionError(
            "Bazel does not support execution of Python interpreters via labels yet"
        )
    elif os.path.isabs(bin_name):
        # Case 2: Absolute path.
        return bin_name
    # Use normpath() to convert slashes to os.sep on Windows.
    elif os.sep in os.path.normpath(bin_name):
        # Case 3: Path is relative to the repo root.
        return os.path.join(module_space, bin_name)
    else:
        # Case 4: Path has to be looked up in the search path.
        return search_path(bin_name)


def create_python_path_entries(python_imports, module_space):
    parts = python_imports.split(":")
    return [module_space] + ["%s/%s" % (module_space, path) for path in parts]


def find_runfiles_root(main_rel_path):
    """Finds the runfiles tree."""
    # When the calling process used the runfiles manifest to resolve the
    # location of this stub script, the path may be expanded. This means
    # argv[0] may no longer point to a location inside the runfiles
    # directory. We should therefore respect RUNFILES_DIR and
    # RUNFILES_MANIFEST_FILE set by the caller.
    runfiles_dir = os.environ.get("RUNFILES_DIR", None)
    if not runfiles_dir:
        runfiles_manifest_file = os.environ.get("RUNFILES_MANIFEST_FILE", "")
        if runfiles_manifest_file.endswith(
            ".runfiles_manifest"
        ) or runfiles_manifest_file.endswith(".runfiles/MANIFEST"):
            runfiles_dir = runfiles_manifest_file[:-9]
    # Be defensive: the runfiles dir should contain our main entry point. If
    # it doesn't, then it must not be our runfiles directory.
    if runfiles_dir and os.path.exists(os.path.join(runfiles_dir, main_rel_path)):
        return runfiles_dir

    stub_filename = sys.argv[0]
    if not os.path.isabs(stub_filename):
        stub_filename = os.path.join(os.getcwd(), stub_filename)

    while True:
        module_space = stub_filename + (".exe" if is_windows() else "") + ".runfiles"
        if os.path.isdir(module_space):
            return module_space

        runfiles_pattern = r"(.*\.runfiles)" + (r"\\" if is_windows() else "/") + ".*"
        matchobj = re.match(runfiles_pattern, stub_filename)
        if matchobj:
            return matchobj.group(1)

        if not os.path.islink(stub_filename):
            break
        target = os.readlink(stub_filename)
        if os.path.isabs(target):
            stub_filename = target
        else:
            stub_filename = os.path.join(os.path.dirname(stub_filename), target)

    raise AssertionError("Cannot find .runfiles directory for %s" % sys.argv[0])


# Returns repository roots to add to the import path.
def get_repositories_imports(module_space, import_all):
    if import_all:
        repo_dirs = [os.path.join(module_space, d) for d in os.listdir(module_space)]
        repo_dirs.sort()
        return [d for d in repo_dirs if os.path.isdir(d)]
    return [os.path.join(module_space, WORKSPACE_NAME)]


def runfiles_envvar(module_space):
    """Finds the runfiles manifest or the runfiles directory.

    Returns:
      A tuple of (var_name, var_value) where var_name is either 'RUNFILES_DIR' or
      'RUNFILES_MANIFEST_FILE' and var_value is the path to that directory or
      file, or (None, None) if runfiles couldn't be found.
    """
    # If this binary is the data-dependency of another one, the other sets
    # RUNFILES_MANIFEST_FILE or RUNFILES_DIR for our sake.
    runfiles = os.environ.get("RUNFILES_MANIFEST_FILE", None)
    if runfiles:
        return ("RUNFILES_MANIFEST_FILE", runfiles)

    runfiles = os.environ.get("RUNFILES_DIR", None)
    if runfiles:
        return ("RUNFILES_DIR", runfiles)

    # Look for the runfiles "output" manifest, argv[0] + ".runfiles_manifest"
    runfiles = module_space + "_manifest"
    if os.path.exists(runfiles):
        return ("RUNFILES_MANIFEST_FILE", runfiles)

    # Look for the runfiles "input" manifest, argv[0] + ".runfiles/MANIFEST"
    # Normally .runfiles_manifest and MANIFEST are both present, but the
    # former will be missing for zip-based builds or if someone copies the
    # runfiles tree elsewhere.
    runfiles = os.path.join(module_space, "MANIFEST")
    if os.path.exists(runfiles):
        return ("RUNFILES_MANIFEST_FILE", runfiles)

    # If running in a sandbox and no environment variables are set, then
    # Look for the runfiles  next to the binary.
    if module_space.endswith(".runfiles") and os.path.isdir(module_space):
        return ("RUNFILES_DIR", module_space)

    return (None, None)


def deduplicate(items):
    """Efficiently filter out duplicates, keeping the first element only."""
    seen = set()
    for it in items:
        if it not in seen:
            seen.add(it)
            yield it


def instrumented_file_paths():
    """Yields tuples of realpath of each instrumented file with the relative path."""
    manifest_filename = os.environ.get("COVERAGE_MANIFEST")
    if not manifest_filename:
        return
    with open(manifest_filename, "r") as manifest:
        for line in manifest:
            filename = line.strip()
            if not filename:
                continue
            try:
                realpath = os.path.realpath(filename)
            except OSError:
                print(
                    "Could not find instrumented file {}".format(filename),
                    file=sys.stderr,
                    flush=True,
                )
                continue
            if realpath != filename:
                print_verbose_coverage("Fixing up {} -> {}".format(realpath, filename))
                yield (realpath, filename)


def unresolve_symlinks(output_filename):
    # type: (str) -> None
    """Replace realpath of instrumented files with the relative path in the lcov output.

    Though we are asking coveragepy to use relative file names, currently
    ignore that for purposes of generating the lcov report (and other reports
    which are not the XML report), so we need to go and fix up the report.

    This function is a workaround for that issue. Once that issue is fixed
    upstream and the updated version is widely in use, this should be removed.

    See https://github.com/nedbat/coveragepy/issues/963.
    """
    substitutions = list(instrumented_file_paths())
    if substitutions:
        unfixed_file = output_filename + ".tmp"
        os.rename(output_filename, unfixed_file)
        with open(unfixed_file, "r") as unfixed:
            with open(output_filename, "w") as output_file:
                for line in unfixed:
                    if line.startswith("SF:"):
                        for realpath, filename in substitutions:
                            line = line.replace(realpath, filename)
                    output_file.write(line)
        os.unlink(unfixed_file)


def _run_py(main_filename, *, args, cwd=None):
    # type: (str, str, list[str], dict[str, str]) -> ...
    """Executes the given Python file using the various environment settings."""

    orig_argv = sys.argv
    orig_cwd = os.getcwd()
    try:
        sys.argv = [main_filename] + args
        if cwd:
            os.chdir(cwd)
        print_verbose("run_py: cwd:", os.getcwd())
        print_verbose("run_py: sys.argv: ", values=sys.argv)
        print_verbose("run_py: os.environ:", mapping=os.environ)
        print_verbose("run_py: sys.path:", values=sys.path)
        runpy.run_path(main_filename, run_name="__main__")
    finally:
        os.chdir(orig_cwd)
        sys.argv = orig_argv


@contextlib.contextmanager
def _maybe_collect_coverage(enable):
    if not enable:
        yield
        return

    import uuid

    import coverage

    coverage_dir = os.environ["COVERAGE_DIR"]
    unique_id = uuid.uuid4()

    # We need for coveragepy to use relative paths.  This can only be configured
    rcfile_name = os.path.join(coverage_dir, ".coveragerc_{}".format(unique_id))
    with open(rcfile_name, "w") as rcfile:
        rcfile.write(
            """[run]
relative_files = True
"""
        )
    try:
        cov = coverage.Coverage(
            config_file=rcfile_name,
            branch=True,
            # NOTE: The messages arg controls what coverage prints to stdout/stderr,
            # which can interfere with the Bazel coverage command. Enabling message
            # output is only useful for debugging coverage support.
            messages=is_verbose_coverage(),
            omit=[
                # Pipes can't be read back later, which can cause coverage to
                # throw an error when trying to get its source code.
                "/dev/fd/*",
            ],
        )
        cov.start()
        try:
            yield
        finally:
            cov.stop()
            lcov_path = os.path.join(coverage_dir, "pylcov.dat")
            cov.lcov_report(
                outfile=lcov_path,
                # Ignore errors because sometimes instrumented files aren't
                # readable afterwards. e.g. if they come from /dev/fd or if
                # they were transient code-under-test in /tmp
                ignore_errors=True,
            )
            if os.path.isfile(lcov_path):
                unresolve_symlinks(lcov_path)
    finally:
        try:
            os.unlink(rcfile_name)
        except OSError as err:
            # It's possible that the profiled program might execute another Python
            # binary through a wrapper that would then delete the rcfile.  Not much
            # we can do about that, besides ignore the failure here.
            print_verbose_coverage("Error removing temporary coverage rc file:", err)


def main():
    print_verbose("initial argv:", values=sys.argv)
    print_verbose("initial cwd:", os.getcwd())
    print_verbose("initial environ:", mapping=os.environ)
    print_verbose("initial sys.path:", values=sys.path)

    main_rel_path = MAIN
    if is_windows():
        main_rel_path = main_rel_path.replace("/", os.sep)

    module_space = find_runfiles_root(main_rel_path)
    print_verbose("runfiles root:", module_space)

    # Recreate the "add main's dir to sys.path[0]" behavior to match the
    # system-python bootstrap / typical Python behavior.
    #
    # Without safe path enabled, when `python foo/bar.py` is run, python will
    # resolve the foo/bar.py symlink to its real path, then add the directory
    # of that path to sys.path. But, the resolved directory for the symlink
    # depends on if the file is generated or not.
    #
    # When foo/bar.py is a source file, then it's a symlink pointing
    # back to the client source directory. This means anything from that source
    # directory becomes importable, i.e. most code is importable.
    #
    # When foo/bar.py is a generated file, then it's a symlink pointing to
    # somewhere under bazel-out/.../bin, i.e. where generated files are. This
    # means only other generated files are importable (not source files).
    #
    # To replicate this behavior, we add main's directory within the runfiles
    # when safe path isn't enabled.
    if not getattr(sys.flags, "safe_path", False):
        prepend_path_entries = [
            os.path.join(module_space, os.path.dirname(main_rel_path))
        ]
    else:
        prepend_path_entries = []
    python_path_entries = create_python_path_entries(IMPORTS_STR, module_space)
    python_path_entries += get_repositories_imports(module_space, IMPORT_ALL)
    python_path_entries = [
        get_windows_path_with_unc_prefix(d) for d in python_path_entries
    ]

    # Remove duplicates to avoid overly long PYTHONPATH (#10977). Preserve order,
    # keep first occurrence only.
    python_path_entries = deduplicate(python_path_entries)

    if is_windows():
        python_path_entries = [p.replace("/", os.sep) for p in python_path_entries]
    else:
        # deduplicate returns a generator, but we need a list after this.
        python_path_entries = list(python_path_entries)

    # We're emulating PYTHONPATH being set, so we insert at the start
    # This isn't a great idea (it can shadow the stdlib), but is the historical
    # behavior.
    runfiles_envkey, runfiles_envvalue = runfiles_envvar(module_space)
    if runfiles_envkey:
        os.environ[runfiles_envkey] = runfiles_envvalue

    main_filename = os.path.join(module_space, main_rel_path)
    main_filename = get_windows_path_with_unc_prefix(main_filename)
    assert os.path.exists(main_filename), (
        "Cannot exec() %r: file not found." % main_filename
    )
    assert os.access(main_filename, os.R_OK), (
        "Cannot exec() %r: file not readable." % main_filename
    )

    # COVERAGE_DIR is set if coverage is enabled and instrumentation is configured
    # for something, though it could be another program executing this one or
    # one executed by this one (e.g. an extension module).
    if os.environ.get("COVERAGE_DIR"):
        cov_tool = find_coverage_entry_point(module_space)
        if cov_tool is None:
            print_verbose_coverage(
                "Coverage was enabled, but python coverage tool was not configured."
                + "To enable coverage, consult the docs at "
                + "https://rules-python.readthedocs.io/en/latest/coverage.html"
            )
        else:
            # Inhibit infinite recursion:
            if "PYTHON_COVERAGE" in os.environ:
                del os.environ["PYTHON_COVERAGE"]

            if not os.path.exists(cov_tool):
                raise EnvironmentError(
                    "Python coverage tool %r not found. "
                    "Try running with VERBOSE_COVERAGE=1 to collect more information."
                    % cov_tool
                )

            # coverage library expects sys.path[0] to contain the library, and replaces
            # it with the directory of the program it starts. Our actual sys.path[0] is
            # the runfiles directory, which must not be replaced.
            # CoverageScript.do_execute() undoes this sys.path[0] setting.
            #
            # Update sys.path such that python finds the coverage package. The coverage
            # entry point is coverage.coverage_main, so we need to do twice the dirname.
            coverage_dir = os.path.dirname(os.path.dirname(cov_tool))
            print_verbose("coverage: adding to sys.path:", coverage_dir)
            python_path_entries.append(coverage_dir)
            python_path_entries = deduplicate(python_path_entries)
    else:
        cov_tool = None

    sys.stdout.flush()
    # NOTE: The sys.path must be modified before coverage is imported/activated
    sys.path[0:0] = prepend_path_entries
    sys.path.extend(python_path_entries)
    with _maybe_collect_coverage(enable=cov_tool is not None):
        # The first arg is this bootstrap, so drop that for the re-invocation.
        _run_py(main_filename, args=sys.argv[1:])
        sys.exit(0)


main()
