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

""

def whl_map_encode(whl_map):
    """Encode a whl_map to attr.string_dict"""
    return {
        k: json.encode(v)
        for k, v in whl_map.items()
    }

def whl_map_decode(whl_map):
    """Decode a whl_map from attr.string_dict"""
    return {
        k: [struct(**v_) for v_ in json.decode(v)]
        for k, v in whl_map.items()
    }
