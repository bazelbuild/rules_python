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

# TODO: Replace this with rules_testing StructSubject
# https://github.com/bazelbuild/rules_testing/issues/53
"""Subject for an arbitrary struct."""

def struct_subject(actual, *, meta, **attr_factories):
    """Creates a struct subject.

    Args:
        actual: struct, the struct to wrap.
        meta: rules_testing ExpectMeta object.
        **attr_factories: dict of attribute names to factory functions. Each
            attribute must exist on the `actual` value. The factory functions
            have the signature `def factory(value, *, meta)`, where `value`
            is the actual attribute value of the struct, and `meta` is
            a rules_testing ExpectMeta object.

    Returns:
        StructSubject object.
    """
    public_attrs = {}
    for name, factory in attr_factories.items():
        if not hasattr(actual, name):
            fail("Struct missing attribute: '{}'".format(name))

        def attr_accessor(*, __name = name, __factory = factory):
            return __factory(
                getattr(actual, __name),
                meta = meta.derive(__name + "()"),
            )

        public_attrs[name] = attr_accessor
    public = struct(
        actual = actual,
        **public_attrs
    )
    return public
