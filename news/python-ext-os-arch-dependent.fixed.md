(toolchains) The `python` extension is re-evaluated when the host OS or CPU
changes, so an output base shared between hosts no longer fails to fetch the
`*_host` interpreter repo.
