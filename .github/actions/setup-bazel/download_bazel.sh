#!/usr/bin/env bash
# Downloads the Bazel binary via Bazelisk with retries on transient network
# errors.
#
# `bazel-contrib/setup-bazel` only configures Bazelisk and restores caches; the
# Bazel binary itself is downloaded by Bazelisk on first invocation. Bazelisk
# retries initial HTTP GET headers (`client.Do`), but does not retry mid-stream
# transfer errors during `io.Copy` (such as HTTP/2 `INTERNAL_ERROR` stream
# resets from `releases.bazel.build`). Running `bazel --version` here triggers
# the download upfront (without starting the Bazel server JVM) and retries on
# transient failures.
set -euo pipefail

max_attempts="${BAZEL_DOWNLOAD_MAX_ATTEMPTS:-5}"
delay="${BAZEL_DOWNLOAD_INITIAL_DELAY:-2}"

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if bazel --version; then
    exit 0
  fi
  if ((attempt < max_attempts)); then
    echo "::warning::Failed to download Bazel (attempt $attempt/$max_attempts); retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
  fi
done

echo "::error::Failed to download Bazel after $max_attempts attempts"
# Remove any empty/partial Bazelisk cache directory created before the failed
# download so `setup-bazel`'s post step does not cache an empty directory.
if [[ -n "${BAZELISK_HOME:-}" ]]; then
  rm -rf "$BAZELISK_HOME"
fi
rm -rf \
  "${XDG_CACHE_HOME:-$HOME/.cache}/bazelisk" \
  "$HOME/Library/Caches/bazelisk" \
  "$HOME/AppData/Local/bazelisk"
exit 1
