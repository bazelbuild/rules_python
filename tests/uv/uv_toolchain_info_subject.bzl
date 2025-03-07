# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""UvToolchainInfo testing subject."""

def uv_toolchain_info_subject(info, *, meta):
    """Creates a new `CcInfoSubject` for a CcInfo provider instance.

    Args:
        info: The CcInfo object.
        meta: ExpectMeta object.

    Returns:
        A `CcInfoSubject` struct.
    """

    # buildifier: disable=uninitialized
    public = struct(
        # go/keep-sorted start
        actual = info,
        # go/keep-sorted end
    )

    # buildifier: @unused
    self = struct(
        actual = info,
        meta = meta,
    )
    return public
