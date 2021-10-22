# Aspect CLI

Aspect is the enterprise-ready command-line interface for powering your developer experience.

`aspect` is a replacement for the `bazel` CLI that comes with Bazel.

![Aspect Build](/logo.svg "Logo")

## Customize for your organization with plugins

aspect-cli uses the same excellent plugin system as Hashicorp's terraform tool.

A plugin allows you to fit aspect into your teams development process
- stamp out new Bazel projects following your local conventions
- error messages point to your internal documentation
- add commands for linting, rebasing, or other common developer workflows
- understand where your developers get stuck and provide help

Plugins are any program that speaks our plugin gRPC protocol.
Read more: TODO

## Interactive

When running in an interactive terminal, aspect-cli helps you out.

It can
- offer to fix problems that block your developers
- suggest better ways to use the tool

## Open source and no lock-in

You can rely on aspect-cli to power your developer experience workflows.

It is free and open-source. It is a superset of what Bazel provides,
so you can always go back to running `bazel` commands.

# Installation:

MacOS: use `curl`

Manual installation:

Download a binary from our [GitHub Releases] page and put it in your PATH.

[Bazel]: http://bazel.build