On the host:

```
sudo apt update
sudo apt install qemu-user-static
```

Then update for x86:

```
export DOCKER_BUILDKIT=1
bazel run //:requirements.update --run_under="//update_helper linux/amd64" --platforms=//platforms:linux_x86
```

And update for arm64:
```
export DOCKER_BUILDKIT=1
bazel run //:requirements.update --run_under="//update_helper linux/arm64/v8" --platforms=//platforms:linux_aarch64
```
