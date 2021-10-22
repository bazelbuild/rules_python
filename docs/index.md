---
title: Aspect CLI
---

Aspect is the enterprise-ready command-line interface for powering your developer experience.

`aspect` is a replacement for the `bazel` CLI that comes with Bazel.

<p align="center">
  <img src="/logo.png" />
</p>

## Customize for your organization with plugins

Every organization has a different engineering culture and developer stack.

![People working together on software](/people.png)

A plugin allows you to fit aspect into your teams development process
- stamp out new Bazel projects following your local conventions
- error messages point to your internal documentation
- add commands for linting, rebasing, or other common developer workflows
- understand where your developers get stuck and provide help

Plugins are any program that speaks our plugin gRPC protocol. We use the [plugin system from HashiCorp](https://github.com/hashicorp/go-plugin).

Read more: TODO

## Interactive

When running in an interactive terminal, aspect-cli helps you out.

![Interactive mode offering to fix an error](/fix_visibility.png)

It can
- offer to fix problems that block your developers
- suggest better ways to use the tool

## Open source and no lock-in

You can rely on aspect-cli to power your developer experience workflows.

It is free and open-source. It is a superset of what Bazel provides,
so you can always go back to running `bazel` commands.

## Expert help is a click away

aspect-cli is sponsored by Aspect Development, a Bazel consulting company.
If your organization needs more help to make your Bazel migration a success,
come find us at [aspect.dev](https://aspect.dev)

# Installation:

## Using a package manager

MacOS with Homebrew: coming soon

Apt: coming soon

## Manual installation

Download a binary from our [GitHub Releases] page and put it in your PATH.

On MacOS you can bypass the "Unknown Developer" dialog by running
`xattr -c $(which aspect)` before launching aspect.

[Bazel]: http://bazel.build
[GitHub Releases]: https://github.com/aspect-dev/aspect-cli/releases
