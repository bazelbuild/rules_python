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

load("@rules_testing//lib:truth.bzl", "subjects")

def parse_modules_subject(info, *, meta):
    """Creates a new `parse_modules_subject` for the parse_modules result instance.

    Method: parse_modules_subject.new

    Args:
        info: The parse_modules result object
        meta: ExpectMeta object.

    Returns:
        A `parse_modules_subject` struct
    """

    # buildifier: disable=uninitialized
    public = struct(
        # go/keep-sorted start
        is_reproducible = lambda *a, **k: _subject_is_reproducible(self, *a, **k),
        exposed_packages = lambda *a, **k: _subject_exposed_packages(self, *a, **k),
        hub_group_map = lambda *a, **k: _subject_hub_group_map(self, *a, **k),
        hub_whl_map = lambda *a, **k: _subject_hub_whl_map(self, *a, **k),
        whl_libraries = lambda *a, **k: _subject_whl_libraries(self, *a, **k),
        whl_mods = lambda *a, **k: _subject_whl_mods(self, *a, **k),
        # go/keep-sorted end
    )
    self = struct(
        actual = info,
        meta = meta,
    )
    return public

def _subject_is_reproducible(self):
    """Returns a `BoolSubject` for the `is_reproducible` attribute.

    Method: parse_modules_subject.direct_pyc_files
    """
    return subjects.bool(
        self.actual.is_reproducible,
        meta = self.meta.derive("is_reproducible()"),
    )

def _subject_exposed_packages(self):
    """Returns a `BoolSubject` for the `exposed_packages` attribute.

    Method: parse_modules_subject.direct_pyc_files
    """
    return subjects.dict(
        self.actual.exposed_packages,
        meta = self.meta.derive("exposed_packages()"),
    )

def _subject_hub_group_map(self):
    """Returns a `BoolSubject` for the `hub_group_map` attribute.

    Method: parse_modules_subject.direct_pyc_files
    """
    return subjects.dict(
        self.actual.hub_group_map,
        meta = self.meta.derive("hub_group_map()"),
    )

def _subject_hub_whl_map(self):
    """Returns a `BoolSubject` for the `hub_whl_map` attribute.

    Method: parse_modules_subject.direct_pyc_files
    """
    return subjects.dict(
        self.actual.hub_whl_map,
        meta = self.meta.derive("hub_whl_map()"),
    )

def _subject_whl_libraries(self):
    """Returns a `BoolSubject` for the `whl_libraries` attribute.

    Method: parse_modules_subject.direct_pyc_files
    """
    return subjects.dict(
        self.actual.whl_libraries,
        meta = self.meta.derive("whl_libraries()"),
    )

def _subject_whl_mods(self):
    """Returns a `BoolSubject` for the `whl_mods` attribute.

    Method: parse_modules_subject.direct_pyc_files
    """
    return subjects.dict(
        self.actual.whl_mods,
        meta = self.meta.derive("whl_mods()"),
    )
