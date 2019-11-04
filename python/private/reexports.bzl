# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Internal re-exports of built-in symbols.

We want to re-export a built-in symbol as if it were defined in a Starlark
file, so that users can for instance do:

```
load("@rules_python//python:defs.bzl", "PyInfo")
```

Unfortunately, we can't just write in defs.bzl

```
PyInfo = PyInfo
```

because the declaration of module-level symbol `PyInfo` makes the builtin
inaccessible. So instead we access the builtin here and export it under a
different name. Then we can load it from defs.bzl and export it there under
the original name.
"""

# Don't use underscore prefix, since that would make the symbol local to this
# file only. Use a non-conventional name to emphasize that this is not a public
# symbol.
# buildifier: disable=name-conventions
internal_PyInfo = PyInfo

# buildifier: disable=name-conventions
internal_PyRuntimeInfo = PyRuntimeInfo
