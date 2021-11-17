# Plugin System

The Aspect CLI has a plugin system that allows engineers to easily build
features on top of Bazel.

## Glossary

- Aspect CLI Core, or simply Core, refers to the core system of the CLI that
  holds the control over the lifecycle of Plugin instances.
- Plugin instance, or sometimes just Plugin, refers to a binary application that
  uses this SDK to extend the functionality of the Core.
- Plugin maintainer refers to a person that maintains a Plugin implementation.
- Aspect CLI SDK refers to the development kit that abstracts away all the
  complexity of implementing a Plugin for the Core.

## Overview

The Core exposes 2 integration categories for Plugins:

1. The Build Event Protocol (BEP).
2. Hooks for the lifecycle of the Core.

## Integration categories

### The Build Event Protocol (BEP)

The BEP is documented
[here](https://docs.bazel.build/versions/main/build-event-protocol.html).
Plugins can listen to the BEP events in real-time. The Core intercepts all the
events from Bazel using the exposed gRPC Build Event Service and re-constructing
the original BEP events. The Core, then, forwards each event to the Plugins.

### Hooks

The Core exposes multiple hook points that can be easily accessed when
implementing Plugins with the SDK. See each SDK documentation for more details
on which hooks are exposed.

## Current SDK

See [the current SDK README](/pkg/plugin/sdk/v1alpha1/README.md).
