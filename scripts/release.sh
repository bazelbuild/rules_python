#!/usr/bin/env bash

set -o pipefail -o errexit -o nounset

rm -rf bin
mkdir -p bin

bazel build --config=release \
    //cmd/aspect:aspect-darwin-amd64 \
    //cmd/aspect:aspect-darwin-arm64 \
    //cmd/aspect:aspect-linux-amd64 \
    //cmd/aspect:aspect-linux-arm64 \
    //cmd/aspect:aspect-windows-amd64
#    //cmd/aspect:aspect-darwin-universal \

#cp -prv bazel-out/*-opt/bin/cmd/aspect/aspect-darwin_universal bin/aspect-darwin
cp -prv bazel-out/*-opt-*/bin/cmd/aspect/aspect-darwin_arm64 bin/aspect-darwin-arm64
cp -prv bazel-out/*-opt-*/bin/cmd/aspect/aspect-darwin_amd64 bin/aspect-darwin-amd64
cp -prv bazel-out/*-opt-*/bin/cmd/aspect/aspect-linux_amd64 bin/aspect-linux-amd64
cp -prv bazel-out/*-opt-*/bin/cmd/aspect/aspect-linux_arm64 bin/aspect-linux-arm64
cp -prv bazel-out/*-opt-*/bin/cmd/aspect/aspect-windows_amd64.exe bin/aspect-windows-amd64.exe

### Print some information about the generated binaries.
echo "== Aspect binaries are ready =="
ls -lh bin/*
file bin/*
echo

echo "== Aspect version output =="
echo "Did you update the tag? git tag -a"
echo "Before releasing, make sure that this is the correct version string:"
"bin/aspect-$(uname -s | tr "[:upper:]" "[:lower:]")-amd64" version
echo
