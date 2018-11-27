# Copyright 2017 The Bazel Authors. All rights reserved.
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

def py_library(*args, **kwargs):
    """See the Bazel core py_library documentation.

    [available here](
    https://docs.bazel.build/versions/master/be/python.html#py_library).
    """
    native.py_library(*args, **kwargs)

def py_binary(*args, **kwargs):
    """See the Bazel core py_binary documentation.

    [available here](
    https://docs.bazel.build/versions/master/be/python.html#py_binary).
    """
    native.py_binary(*args, **kwargs)

def py_test(*args, **kwargs):
    """See the Bazel core py_test documentation.

    [available here](
    https://docs.bazel.build/versions/master/be/python.html#py_test).
    """
    native.py_test(*args, **kwargs)
