# How to contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Getting started

Before we can work on the code, we need to get a copy of it and setup some
local environment and tools.

First, fork the code to your user and clone your fork. This gives you a private
playground where you can do any edits you'd like. For this guide, we'll use
the [GitHub `gh` tool](https://github.com/cli/cli)
([Linux install](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)).
(More advanced users may prefer the GitHub UI and raw `git` commands).

```shell
gh repo fork bazelbuild/rules_python --clone --remote
```

Next, make sure you have a new enough version of Python installed that supports the
various code formatters and other devtools. For a quick start,
[install pyenv](https://github.com/pyenv/pyenv-installer) and
at least Python 3.9.15:

```shell
curl https://pyenv.run | bash
pyenv install 3.9.15
pyenv shell 3.9.15
```

## Development workflow

It's suggested that you create what is called a "feature/topic branch" in your
fork when you begin working on code you want to eventually send or code review.

```
git checkout main # Start our branch from the latest code
git checkout -b my-feature # Create and switch to our feature branch
git push origin my-feature # Cause the branch to be created in your fork.
```

From here, you then edit code and commit to your local branch. If you want to
save your work to github, you use `git push` to do so:

```
git push origin my-feature
```

Once the code is in your github repo, you can then turn it into a Pull Request
to the actual rules_python project and begin the code review process.


## Running tests

Running tests is particularly easy thanks to Bazel, simply run:

```
bazel test //...
```

And it will run all the tests it can find. The first time you do this, it will
probably take long time because various dependencies will need to be downloaded
and setup. Subsequent runs will be faster, but there are many tests, and some of
them are slow. If you're working on a particular area of code, you can run just
the tests in those directories instead, which can speed up your edit-run cycle.

Note that there are tests to verify generated documentation is correct -- if
you're modifying the signature of a public function, these tests will likely
fail and you'll need to [regenerate the api docs](#documentation).

## Formatting

Starlark files should be formatted by
[buildifier](https://github.com/bazelbuild/buildtools/blob/master/buildifier/README.md).
Otherwise the Buildkite CI will fail with formatting/linting violations.
We suggest using a pre-commit hook to automate this.
First [install pre-commit](https://pre-commit.com/#installation),
then run

```shell
pre-commit install
```

### Running buildifer manually

You can also run buildifier manually. To do this,
[install buildifier](https://github.com/bazelbuild/buildtools/blob/master/buildifier/README.md),
and run the following command:

```shell
$ buildifier --lint=fix --warnings=native-py -warnings=all WORKSPACE
```

Replace the argument "WORKSPACE" with the file that you are linting.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution,
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult [GitHub Help] for more
information on using pull requests.

[GitHub Help]: https://help.github.com/articles/about-pull-requests/

### Commit messages

Commit messages (upon merging) and PR messages should follow the [Conventional
Commits](https://www.conventionalcommits.org/) style:

```
type(scope)!: <summary>

<body>

BREAKING CHANGE: <summary>
```

Where `(scope)` is optional, and `!` is only required if there is a breaking change.
If a breaking change is introduced, then `BREAKING CHANGE:` is required.

Common `type`s:

* `build:` means it affects the building or development workflow.
* `docs:` means only documentation is being added, updated, or fixed.
* `feat:` means a user-visible feature is being added.
* `fix:` means a user-visible behavior is being fixed.
* `refactor:` means some sort of code cleanup that doesn't change user-visible behavior.
* `revert:` means a prior change is being reverted in some way.
* `test:` means only tests are being added.

For the full details of types, see
[Conventional Commits](https://www.conventionalcommits.org/).

## Generated files

Some checked-in files are generated and need to be updated when a new PR is
merged.

### Documentation

To regenerate the content under the `docs/` directory, run this command:

```shell
bazel run //docs:update
```

This needs to be done whenever the docstrings in the corresponding .bzl files
are changed; a test failure will remind you to run this command when needed.

## Core rules

The bulk of this repo is owned and maintained by the Bazel Python community.
However, since the core Python rules (`py_binary` and friends) are still
bundled with Bazel itself, the Bazel team retains ownership of their stubs in
this repository. This will be the case at least until the Python rules are
fully migrated to Starlark code.

Practically, this means that a Bazel team member should approve any PR
concerning the core Python logic. This includes everything under the `python/`
directory except for `pip.bzl` and `requirements.txt`.

Issues should be triaged as follows:

- Anything concerning the way Bazel implements the core Python rules should be
  filed under [bazelbuild/bazel](https://github.com/bazelbuild/bazel), using
  the label `team-Rules-python`.

- If the issue specifically concerns the rules_python stubs, it should be filed
  here in this repository and use the label `core-rules`.

- Anything else, such as feature requests not related to existing core rules
  functionality, should also be filed in this repository but without the
  `core-rules` label.

## FAQ

### Installation errors when during `git commit`

If you did `pre-commit install`, various tools are run when you do `git commit`.
This might show as an error such as:

```
[INFO] Installing environment for https://github.com/psf/black.
[INFO] Once installed this environment will be reused.
[INFO] This may take a few minutes...
An unexpected error has occurred: CalledProcessError: command: ...
```

To fix, you'll need to figure out what command is failing and why. Because these
are tools that run locally, its likely you'll need to fix something with your
environment or the installation of the tools. For Python tools (e.g. black or
isort), you can try using a different Python version in your shell by using
tools such as [pyenv](https://github.com/pyenv/pyenv).
