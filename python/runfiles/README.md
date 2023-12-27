# bazel-runfiles library

This is a Bazel Runfiles lookup library for Bazel-built Python binaries and tests.

Learn about runfiles: read [Runfiles guide](https://bazel.build/extending/rules#runfiles)
or watch [Fabian's BazelCon talk](https://www.youtube.com/watch?v=5NbgUMH1OGo).

## Typical Usage

1. Depend on this runfiles library from your build rule, like you would other third-party libraries:

    ```python
    py_binary(
        name = "my_binary",
        # ...
        deps = ["@rules_python//python/runfiles"],
    )
    ```

2. Import the runfiles library:

    ```python
        from rules_python.python.runfiles import Runfiles
    ```

3. Create a `Runfiles` object and use `Rlocation` to look up runfile paths:

    ```python
    r = Runfiles.Create()
    # ...
    with open(r.Rlocation("my_workspace/path/to/my/data.txt"), "r") as f:
        contents = f.readlines()
        # ...
    ```

    The code above creates a manifest- or directory-based implementation based on the environment variables in `os.environ`. See `Runfiles.Create()` for more info.

    If you want to explicitly create a manifest- or directory-based
    implementation, you can do so as follows:

    ```python
    r1 = Runfiles.CreateManifestBased("path/to/foo.runfiles_manifest")

    r2 = Runfiles.CreateDirectoryBased("path/to/foo.runfiles/")
    ```

    If you want to start subprocesses, and the subprocess can't automatically
    find the correct runfiles directory, you can explicitly set the right
    environment variables for them:

    ```python
    import subprocess
    from rules_python.python.runfiles import Runfiles

    r = Runfiles.Create()
    env = {}
    # ...
    env.update(r.EnvVars())
    p = subprocess.run(
        [r.Rlocation("path/to/binary")],
        env=env,
        # ...
    )
    ```
