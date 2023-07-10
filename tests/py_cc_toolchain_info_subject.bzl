# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""PyCcToolchainInfo testing subject."""

# TODO: Load this through truth.bzl#subjects when made available
# https://github.com/bazelbuild/rules_testing/issues/54
load("@rules_testing//lib/private:dict_subject.bzl", "DictSubject")  # buildifier: disable=bzl-visibility

# TODO: Load this through truth.bzl#subjects when made available
# https://github.com/bazelbuild/rules_testing/issues/54
load("@rules_testing//lib/private:str_subject.bzl", "StrSubject")  # buildifier: disable=bzl-visibility
load(":struct_subject.bzl", "struct_subject")

def _py_cc_toolchain_info_subject_new(info, *, meta):
    # buildifier: disable=uninitialized
    public = struct(
        headers = lambda *a, **k: _py_cc_toolchain_info_subject_headers(self, *a, **k),
        python_version = lambda *a, **k: _py_cc_toolchain_info_subject_python_version(self, *a, **k),
        actual = info,
    )
    self = struct(actual = info, meta = meta)
    return public

def _py_cc_toolchain_info_subject_headers(self):
    return struct_subject(
        self.actual.headers,
        meta = self.meta.derive("headers()"),
        providers_map = DictSubject.new,
    )

def _py_cc_toolchain_info_subject_python_version(self):
    return StrSubject.new(
        self.actual.python_version,
        meta = self.meta.derive("python_version()"),
    )

# Disable this to aid doc generation
# buildifier: disable=name-conventions
PyCcToolchainInfoSubject = struct(
    new = _py_cc_toolchain_info_subject_new,
)
