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

RELEASE_URL = "https://github.com/indygreg/python-build-standalone/releases/download/20220227"
RELEASE_DATE = "20220227"

# buildifier: disable=unsorted-dict-items
TOOL_VERSIONS = {
    "3.8.12": {
        "x86_64-apple-darwin": "sha256-8yP7xVgDXBOoXOImfQ+tnokoImjsuBDjZP/x0KB51SU=",
        "x86_64-pc-windows-msvc": "sha256-kk+f1R/2zMUz7Y6WxUYXaNpXges9/BHYRvnjAPq0Tto=",
        "x86_64-unknown-linux-gnu": "sha256-W+nG1h4ji5Df2UdVBRwNOi2AI+v/20sPpOj+3QmmyrY=",
    },
    "3.9.10": {
        "aarch64-apple-darwin": "sha256-rWbCo+cmMUfgRqMmlN57iXpG+wEkQJ0p06k+3mMciu4=",
        "x86_64-apple-darwin": "sha256-/a9ZQUJEYCnjFKm+uR8ax1r4ZjILULi5aBgeWSVQzWg=",
        "x86_64-pc-windows-msvc": "sha256-W8Zc4CNhS/SWpnSOQdypNLcPxfrG36zEaqjbytdyr8I=",
        "x86_64-unknown-linux-gnu": "sha256-RVCJzFdr2aWNtF6RnR/IZ+zbsCCAZ9/8hFzJu/BwG3A=",
    },
    "3.10.2": {
        "aarch64-apple-darwin": "sha256-FAms2aUG4tHTtlwUiNtOQNjxnQmn3wmWZ8h6UG9xwO8=",
        "x86_64-apple-darwin": "sha256-gUatQ5BxDsabMWpWSZEt8CR9NfSkLiqpYVv/2Hs+I1o=",
        "x86_64-pc-windows-msvc": "sha256-opPFg43ZyEOKhDcvuV3al1LfY5KKiirlFkOPGH+JVn0=",
        "x86_64-unknown-linux-gnu": "sha256-m2TsoqlPev+UCa1wvap/u/gUhpJmLnZEAYg5V5Q2IN0=",
    },
}

# buildifier: disable=unsorted-dict-items
MINOR_MAPPING = {
    "3.8": "3.8.12",
    "3.9": "3.9.10",
    "3.10": "3.10.2",
}
