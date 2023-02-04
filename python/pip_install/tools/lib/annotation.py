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

import json
import logging
from collections import OrderedDict
from pathlib import Path
from typing import Any, Dict, List


class Annotation(OrderedDict):
    """A python representation of `@rules_python//python:pip.bzl%package_annotation`"""

    def __init__(self, content: Dict[str, Any]) -> None:

        missing = []
        ordered_content = OrderedDict()
        for field in (
            "additive_build_content",
            "copy_executables",
            "copy_files",
            "data",
            "data_exclude_glob",
            "srcs_exclude_glob",
        ):
            if field not in content:
                missing.append(field)
                continue
            ordered_content.update({field: content.pop(field)})

        if missing:
            raise ValueError("Data missing from initial annotation: {}".format(missing))

        if content:
            raise ValueError(
                "Unexpected data passed to annotations: {}".format(
                    sorted(list(content.keys()))
                )
            )

        return OrderedDict.__init__(self, ordered_content)

    @property
    def additive_build_content(self) -> str:
        return self["additive_build_content"]

    @property
    def copy_executables(self) -> Dict[str, str]:
        return self["copy_executables"]

    @property
    def copy_files(self) -> Dict[str, str]:
        return self["copy_files"]

    @property
    def data(self) -> List[str]:
        return self["data"]

    @property
    def data_exclude_glob(self) -> List[str]:
        return self["data_exclude_glob"]

    @property
    def srcs_exclude_glob(self) -> List[str]:
        return self["srcs_exclude_glob"]


class AnnotationsMap:
    """A mapping of python package names to [Annotation]"""

    def __init__(self, json_file: Path):
        content = json.loads(json_file.read_text())

        self._annotations = {pkg: Annotation(data) for (pkg, data) in content.items()}

    @property
    def annotations(self) -> Dict[str, Annotation]:
        return self._annotations

    def collect(self, requirements: List[str]) -> Dict[str, Annotation]:
        unused = self.annotations
        collection = {}
        for pkg in requirements:
            if pkg in unused:
                collection.update({pkg: unused.pop(pkg)})

        if unused:
            logging.warning(
                "Unused annotations: {}".format(sorted(list(unused.keys())))
            )

        return collection


def annotation_from_str_path(path: str) -> Annotation:
    """Load an annotation from a json encoded file

    Args:
        path (str): The path to a json encoded file

    Returns:
        Annotation: The deserialized annotations
    """
    json_file = Path(path)
    content = json.loads(json_file.read_text())
    return Annotation(content)


def annotations_map_from_str_path(path: str) -> AnnotationsMap:
    """Load an annotations map from a json encoded file

    Args:
        path (str): The path to a json encoded file

    Returns:
        AnnotationsMap: The deserialized annotations map
    """
    return AnnotationsMap(Path(path))
