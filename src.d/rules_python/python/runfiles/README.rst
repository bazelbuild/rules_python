bazel-runfiles library
======================

This is a Bazel Runfiles lookup library for Bazel-built Python binaries and tests.

Learn about runfiles: read `Runfiles guide <https://bazel.build/extending/rules#runfiles>`_
or watch `Fabian's BazelCon talk <https://www.youtube.com/watch?v=5NbgUMH1OGo>`_.

Typical Usage
-------------

1.  Add the 'bazel-runfiles' dependency along with other third-party dependencies, for example in your
    ``requirements.txt`` file.

2.  Depend on this runfiles library from your build rule, like you would other third-party libraries::

      py_binary(
          name = "my_binary",
          ...
          deps = [requirement("bazel-runfiles")],
      )

3.  Import the runfiles library::

      import runfiles  # not "from runfiles import runfiles"

4.  Create a Runfiles object and use rlocation to look up runfile paths::

      r = runfiles.Create()
      ...
      with open(r.Rlocation("my_workspace/path/to/my/data.txt"), "r") as f:
        contents = f.readlines()
        ...

    The code above creates a manifest- or directory-based implementations based
    on the environment variables in os.environ. See `Create()` for more info.

    If you want to explicitly create a manifest- or directory-based
    implementations, you can do so as follows::

      r1 = runfiles.CreateManifestBased("path/to/foo.runfiles_manifest")

      r2 = runfiles.CreateDirectoryBased("path/to/foo.runfiles/")

    If you want to start subprocesses, and the subprocess can't automatically
    find the correct runfiles directory, you can explicitly set the right
    environment variables for them::

      import subprocess
      import runfiles

      r = runfiles.Create()
      env = {}
      ...
      env.update(r.EnvVars())
      p = subprocess.Popen([r.Rlocation("path/to/binary")], env, ...)