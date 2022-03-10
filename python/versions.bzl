# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""The Python versions we use for the toolchains.
"""

# Values returned by https://bazel.build/rules/lib/repository_os.
MACOS_NAME = "mac os"
LINUX_NAME = "linux"
WINDOWS_NAME = "windows"

DEFAULT_RELEASE_BASE_URL = "https://github.com/indygreg/python-build-standalone/releases/download"

def get_release_url(platform, python_version, base_url = DEFAULT_RELEASE_BASE_URL):
    release_filename = TOOL_VERSIONS[python_version]["url"].format(
        platform = platform,
        python_version = python_version,
        build = "static-install_only" if (WINDOWS_NAME in platform) else "install_only",
    )
    url = "/".join([base_url, release_filename])
    return (release_filename, url)

# When updating the versions and releases, run the following command to get
# the hashes:
#   bazel run //python/private:print_toolchains_checksums
#
# buildifier: disable=unsorted-dict-items
TOOL_VERSIONS = {
    "3.8.10": {
        "url": "20210506/cpython-{python_version}-{platform}-pgo+lto-20210506T0943.tar.zst",
        "sha256": {
            "x86_64-apple-darwin": "8d06bec08db8cdd0f64f4f05ee892cf2fcbc58cfb1dd69da2caab78fac420238",
            "x86_64-unknown-linux-gnu": "aec8c4c53373b90be7e2131093caa26063be6d9d826f599c935c0e1042af3355",
        },
    },
    "3.8.12": {
        "url": "20220227/cpython-{python_version}+20220227-{platform}-{build}.tar.gz",
        "sha256": {
            "x86_64-apple-darwin": "f323fbc558035c13a85ce2267d0fad9e89282268ecb810e364fff1d0a079d525",
            "x86_64-pc-windows-msvc": "924f9fd51ff6ccc533ed8e96c5461768da5781eb3dfc11d846f9e300fab44eda",
            "x86_64-unknown-linux-gnu": "5be9c6d61e238b90dfd94755051c0d3a2d8023ebffdb4b0fa4e8fedd09a6cab6",
        },
    },
    "3.9.10": {
        "url": "20220227/cpython-{python_version}+20220227-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "ad66c2a3e7263147e046a32694de7b897a46fb0124409d29d3a93ede631c8aee",
            "x86_64-apple-darwin": "fdaf594142446029e314a9beb91f1ac75af866320b50b8b968181e592550cd68",
            "x86_64-pc-windows-msvc": "5bc65ce023614bf496a6748e41dca934b70fc5fac6dfacc46aa8dbcad772afc2",
            "x86_64-unknown-linux-gnu": "455089cc576bd9a58db45e919d1fc867ecdbb0208067dffc845cc9bbf0701b70",
        },
    },
    "3.10.2": {
        "url": "20220227/cpython-{python_version}+20220227-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "1409acd9a506e2d1d3b65c1488db4e40d8f19d09a7df099667c87a506f71c0ef",
            "x86_64-apple-darwin": "8146ad4390710ec69b316a5649912df0247d35f4a42e2aa9615bffd87b3e235a",
            "x86_64-pc-windows-msvc": "a293c5838dd9c8438a84372fb95dda9752df63928a8a2ae516438f187f89567d",
            "x86_64-unknown-linux-gnu": "9b64eca2a94f7aff9409ad70bdaa7fbbf8148692662e764401883957943620dd",
        },
    },
}

# buildifier: disable=unsorted-dict-items
MINOR_MAPPING = {
    "3.8": "3.8.12",
    "3.9": "3.9.10",
    "3.10": "3.10.2",
}

PLATFORMS = {
    "aarch64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
        os_name = MACOS_NAME,
        # Matches the value returned from:
        # repository_ctx.execute(["uname", "-m"]).stdout.strip()
        arch = "arm64",
    ),
    "x86_64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
        os_name = MACOS_NAME,
        arch = "x86_64",
    ),
    "x86_64-pc-windows-msvc": struct(
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
        os_name = WINDOWS_NAME,
        arch = "x86_64",
    ),
    "x86_64-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
        os_name = LINUX_NAME,
        arch = "x86_64",
    ),
}

def print_toolchains_checksums(name):
    native.genrule(
        name = name,
        srcs = [],
        outs = ["print_toolchains_checksums.sh"],
        cmd = """\
cat > "$@" <<'EOF'
#!/bin/bash

set -o errexit -o nounset -o pipefail

echo "Fetching hashes..."

{commands}
EOF
        """.format(
            commands = "\n".join([
                _commands_for_version(python_version)
                for python_version in TOOL_VERSIONS.keys()
            ]),
        ),
        executable = True,
    )

def _commands_for_version(python_version):
    return "\n".join([
        "echo \"{python_version}: {platform}: $$(curl --location --fail {release_url_sha256} 2>/dev/null || curl --location --fail {release_url} 2>/dev/null | shasum -a 256 | awk '{{ print $$1 }}')\"".format(
            python_version = python_version,
            platform = platform,
            release_url = get_release_url(platform, python_version)[1],
            release_url_sha256 = get_release_url(platform, python_version)[1] + ".sha256",
        )
        for platform in TOOL_VERSIONS[python_version]["sha256"].keys()
    ])
