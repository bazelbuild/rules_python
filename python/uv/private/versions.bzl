# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Version and integrity information for downloaded artifacts"""

UV_PLATFORMS = {
    "aarch64-apple-darwin": struct(
        default_repo_name = "uv_darwin_aarch64",
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
    ),
    "aarch64-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_aarch64",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:aarch64",
        ],
    ),
    "powerpc64le-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_ppc",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:ppc",
        ],
    ),
    "s390x-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_s390x",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:s390x",
        ],
    ),
    "x86_64-apple-darwin": struct(
        default_repo_name = "uv_darwin_x86_64",
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
    ),
    "x86_64-pc-windows-msvc": struct(
        default_repo_name = "uv_windows_x86_64",
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    ),
    "x86_64-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_x86_64",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
}

# From: https://github.com/astral-sh/uv/releases
UV_TOOL_VERSIONS = {
    "0.2.23": {
        "aarch64-apple-darwin": struct(
            sha256 = "1d41beb151ace9621a0e729d661cfb04d6375bffdaaf0e366d1653576ce3a687",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "c35042255239b75d29b9fd4b0845894b91284ed3ff90c2595d0518b4c8902329",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "ca16c9456d297e623164e3089d76259c6d70ac40c037dd2068accc3bb1b09d5e",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "55f8c2aa089f382645fce9eed3ee002f2cd48de4696568e7fd63105a02da568c",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "960d2ae6ec31bcf5da3f66083dedc527712115b97ee43eae903d74a43874fa72",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "66f80537301c686a801b91468a43dbeb0881bd6d51857078c24f29e5dca8ecf1",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "4384db514959beb4de1dcdf7f1f2d5faf664f7180820b0e7a521ef2147e33d1d",
        ),
    },
}
