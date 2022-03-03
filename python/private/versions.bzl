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

_RELEASE_URL = "https://github.com/indygreg/python-build-standalone/releases/download/20220227"
_RELEASE_FILENAME_TEMPLATE = "cpython-{python_version}+20220227-{platform}-{build}.tar.gz"

def get_release_url(platform, python_version):
    release_filename = _RELEASE_FILENAME_TEMPLATE.format(
        platform = platform,
        python_version = python_version,
        build = "static-install_only" if ("windows" in platform) else "install_only",
    )
    url = "{release_url}/{release_filename}".format(
        release_url = _RELEASE_URL,
        release_filename = release_filename,
    )
    return (release_filename, url)

# When updating the versions and releases, run the following command to get
# the hashes:
#   bazel run //python/private:print_toolchains_checksums
#
# buildifier: disable=unsorted-dict-items
TOOL_VERSIONS = {
    "3.8.12": {
        "x86_64-apple-darwin": "f323fbc558035c13a85ce2267d0fad9e89282268ecb810e364fff1d0a079d525",
        "x86_64-pc-windows-msvc": "924f9fd51ff6ccc533ed8e96c5461768da5781eb3dfc11d846f9e300fab44eda",
        "x86_64-unknown-linux-gnu": "5be9c6d61e238b90dfd94755051c0d3a2d8023ebffdb4b0fa4e8fedd09a6cab6",
    },
    "3.9.10": {
        "aarch64-apple-darwin": "ad66c2a3e7263147e046a32694de7b897a46fb0124409d29d3a93ede631c8aee",
        "x86_64-apple-darwin": "fdaf594142446029e314a9beb91f1ac75af866320b50b8b968181e592550cd68",
        "x86_64-pc-windows-msvc": "5bc65ce023614bf496a6748e41dca934b70fc5fac6dfacc46aa8dbcad772afc2",
        "x86_64-unknown-linux-gnu": "455089cc576bd9a58db45e919d1fc867ecdbb0208067dffc845cc9bbf0701b70",
    },
    "3.10.2": {
        "aarch64-apple-darwin": "1409acd9a506e2d1d3b65c1488db4e40d8f19d09a7df099667c87a506f71c0ef",
        "x86_64-apple-darwin": "8146ad4390710ec69b316a5649912df0247d35f4a42e2aa9615bffd87b3e235a",
        "x86_64-pc-windows-msvc": "a293c5838dd9c8438a84372fb95dda9752df63928a8a2ae516438f187f89567d",
        "x86_64-unknown-linux-gnu": "9b64eca2a94f7aff9409ad70bdaa7fbbf8148692662e764401883957943620dd",
    },
}

# buildifier: disable=unsorted-dict-items
MINOR_MAPPING = {
    "3.8": "3.8.12",
    "3.9": "3.9.10",
    "3.10": "3.10.2",
}

def print_toolchains_checksums(name):
    native.genrule(
        name = name,
        srcs = [],
        outs = ["print_toolchains_checksums.sh"],
        cmd = """\
cat > "$@" <<EOF
#!/bin/bash

set -o errexit -o nounset -o pipefail

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
        "echo \"{python_version}: {platform}: $$(curl --location {release_url_sha256} 2>/dev/null)\"".format(
            python_version = python_version,
            platform = platform,
            release_url_sha256 = get_release_url(platform, python_version)[1] + ".sha256",
        )
        for platform in TOOL_VERSIONS[python_version].keys()
    ])
