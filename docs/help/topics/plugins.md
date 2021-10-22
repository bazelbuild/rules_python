# Aspect CLI Plugins

NB: plugin support is still in design phase, the documentation below may not yet
apply.

The plugin system is inspired by the excellent system developed for HashiCorp's
`terraform` CLI.

## High-level design

A plugin is any program with a gRPC server that implements our plugin protocol.
We provide convenient support for writing plugins in Go, but this is not
required. Plugins are hosted and versioned independently from the aspect CLI.

The aspect CLI process spawns the plugin as a subprocess, then connects as a
gRPC client to it. The client and server run a negotiation protocol to determine
version compatibility and what capabilities the plugin provides.

## Plugin configuration

In your [aspect CLI config], list the plugins you'd like to install. You can use
semver ranges to constrain the versions which can be used. When aspect runs, it
will prompt you to re-lock the dependencies to exact versions if they have
changed. We also verify the checksum of the plugin contents against what was
first installed.

> The locking semantics follow the [Trust on first use] approach.

[trust on first use]: https://en.wikipedia.org/wiki/Trust_on_first_use
[aspect cli config]: TODO

## Plugin discovery

TODO: where we search to resolve plugins on disk or fetch them from network
TODO: how to author a local plugin and resolve it for development

## Capabilities

Plugins can implement any of the following:

- BuildComplete
