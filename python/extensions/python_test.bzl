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

"""Python toolchain module extensions for use with bzlmod.

::::{topic} Basic usage

The simplest way to configure the toolchain with `rules_python` is as follows.

```starlark
python_test = use_extension("@rules_python//python/extensions:python_test.bzl", "python_test")
python_test.configure(
    coveragerc = ".coveragerc",
)
use_repo(python_test, "py_test_toolchain")
register_toolchains("@py_test_toolchain//:all")
```
"""

load("//python/private:python_test.bzl", _python_test = "python_test")

python_test = _python_test
