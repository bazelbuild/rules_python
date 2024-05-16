# Precompiling

Precompiling is compiling Python source files (`.py` files) into byte code (`.pyc`
files) at build
time instead of runtime. Doing it at build time can improve performance by
skipping that work at runtime.

Precompiling is enabled by default, so there typically isn't anything special
you must do to use it.


## Overhead of precompiling

While precompiling helps runtime performance, it has two main costs:
1. Increasing the size (count and disk usage) of runfiles. It approximately
   double the count of the runfiles because for every `.py` file, there is also
   a `.pyc` file. Compiled files are generally around the same size as the
   source files, so it approximately doubles the disk usage.
2. Precompiling requires running an extra action at build time. While
   compiling itself isn't that expensive, the overhead can become noticable
   as more files need to be compiled.

## Binary-level opt-in

Because of the costs of precompiling, it may not be feasible to globally enable it
for your repo for everything. For example, some binaries may be
particularly large, and doubling the number of runfiles isn't doable.

If this is the case, there's an alternative way to more selectively and
incrementally control precompiling on a per-binry basis.

To use this approach, the two basic steps are:
1. Disable pyc files from being automatically added to runfiles:
   `--@rules_python//python/config_settings:precompile_add_to_runfiles=decided_elsewhere`,
2. Set the `pyc_collection` attribute on the binaries/tests that should or should
   not use precompiling.

The default for the `pyc_collection` attribute is controlled by a flag, so you
can use an opt-in or opt-out approach by setting the flag:
* targets must opt-out: `--@rules_python//python/config_settings:pyc_collection=include_pyc`,
* targets must opt-in: `--@rules_python//python/config_settings:pyc_collection=disabled`,

## Advanced precompiler customization

The default implementation of the precompiler is a persistent, multiplexed,
sandbox-aware, cancellation-enabled, json-protocol worker that uses the same
interpreter as the target toolchain. This works well for local builds, but may
not work as well for remote execution builds. To customize the precompiler, two
mechanisms are available:

* The exec tools toolchain allows customizing the precompiler binary used with
  the `precompiler` attribute. Arbitrary binaries are supported.
* The execution requirements can be customized using
  `--@rules_python//tools/precompiler:execution_requirements`. This is a list
  flag that can be repeated. Each entry is a key=value that is added to the
  execution requirements of the `PyPrecompile` action. Note that this flag
  is specific to the rules_python precompiler. If a custom binary is used,
  this flag will have to be propagated from the custom binary using the
  `testing.ExecutionInfo` provider; refer to the `py_interpreter_program` an

The default precompiler implementation is an asynchronous/concurrent
implementation. If you find it has bugs or hangs, please report them. In the
meantime, the flag `--worker_extra_flag=PyPrecompile=--worker_impl=serial` can
be used to switch to a synchronous/serial implementation that may not perform
as well, but is less likely to have issues.