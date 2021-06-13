# aspect-cli

This is the frontend for the Aspect build tool.
It is currently just a wrapper around bazelisk or bazel, meant to install in tools/bazel.

In the future, we might totally replace the bazel C++ client, and this tool would be a gRPC client of the bazel server.

## TODOs

- [ ] figure out how to cut and host a release
      GH Action to cut/publish release whenever a tag is pushed upstream
- [ ] document lots of ways to install, including a bash one-liner
- [ ] help user ensure bash/zsh completion working
- [ ] warn user if Bazel version is floating 
      (no bazelisk, or using latest in .bazelversion, or no .bazelversion)

# Use Cases

## When I am confused by bazel

I can find that Aspect is an easier-to-use wrapper and feel motivated and comfortable to try it immediately.

From aspect.build/install I quickly pick an Installation option, and am guided through to successful install.

The first time I run `aspect` in interactive mode,
- I choose whether I want to install for all users of my workspace, in which case a bootstrap bit is added to tools/bazel ensuring that the tool is downloaded and spawned for anyone cloning my repo.

## When I run bare `bazel`

## When I run bare `bazel build`

## When I run bare `bazel test`
