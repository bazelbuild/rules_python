# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""
Functions for inspecting the test environment.

Currently contains:
* A check to see if we are on Bazel 6.0+
"""

def _is_bazel_6_or_higher():
    return testing.ExecutionInfo == testing.ExecutionInfo

test_env = struct(
    is_bazel_6_or_higher = _is_bazel_6_or_higher,
)
