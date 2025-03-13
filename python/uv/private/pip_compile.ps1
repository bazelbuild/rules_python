$out=replace
if [[ -n "$env:BUILD_WORKSPACE_DIRECTORY" ]]; then
    $out="$env:BUILD_WORKSPACE_DIRECTORY\$out"
else
    Copy-Item "$out" "bazel_out"
    out="bazel_out"
fi
& uv pip compile --output-file "$out" $args
