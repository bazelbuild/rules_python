# Copyright 2023 Jeremy Volkman. All rights reserved.
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
Stuff to define a target Python environment.

See https://peps.python.org/pep-0508/#environment-markers
"""
from dataclasses import asdict
from dataclasses import dataclass
from typing import Any
from typing import Dict
from typing import List

from pip._internal.models.target_python import TargetPython


@dataclass
class TargetEnv:
    name: str
    implementation: str
    version: str
    abis: List[str]
    platforms: List[str]
    compatibility_tags: List[str]
    markers: Dict[str, str]
    python_compatible_with: List[str]
    flag_values: Dict[str, str]

    @staticmethod
    def from_target_python(
        name: str,
        target_python: TargetPython,
        markers: Dict[str, str],
        python_compatible_with: List[str],
        flag_values: Dict[str, str],
    ) -> "TargetEnv":
        all_markers = guess_environment_markers(target_python)
        for key, val in markers.items():
            if key not in all_markers:
                raise ValueError(f"Invalid marker: {key}")
            all_markers[key] = val

        return TargetEnv(
            name=name,
            implementation=target_python.implementation,
            version=".".join((str(i) for i in target_python.py_version_info)),
            abis=target_python.abis,
            platforms=target_python.platforms,
            compatibility_tags=[str(t) for t in target_python.get_sorted_tags()],
            markers=all_markers,
            python_compatible_with=python_compatible_with,
            flag_values=flag_values,
        )

    @property
    def target_python(self) -> TargetPython:
        return TargetPython(
            platforms=self.platforms,
            py_version_info=tuple(int(p) for p in self.version.split(".")[:3]),
            abis=self.abis,
            implementation=self.implementation,
        )

    @staticmethod
    def from_dict(data: Dict[str, Any]) -> "TargetEnv":
        return TargetEnv(**data)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


def normalize_os(py: TargetPython) -> str:
    for platform in py.platforms:
        if platform.startswith("linux"):
            return "linux"
        elif platform.startswith("manylinux"):
            return "linux"
        elif platform.startswith("macos"):
            return "darwin"
        elif platform.startswith("win"):
            return "windows"
    return ""


def normalize_arch(py: TargetPython) -> str:
    for platform in py.platforms:
        if "x86_64" in platform:
            return "x86_64"
        elif "amd64" in platform:
            return "x86_64"
        elif "aarch64" in platform:
            return "aarch64"
        elif "arm64" in platform:
            return "aarch64"
        elif "x86" in platform:
            return "x86"
        elif "i386" in platform:
            return "x86"
        elif "i686" in platform:
            return "x86"
        elif platform == "win32":
            return "x86"
    return ""


def guess_os_name(py: TargetPython) -> str:
    return {
        "linux": "posix",
        "darwin": "posix",
        "windows": "nt",
    }.get(normalize_os(py), "")


def guess_sys_platform(py: TargetPython) -> str:
    return {
        "linux": "linux",
        "darwin": "darwin",
        "windows": "win32",
    }.get(normalize_os(py), "")


def guess_platform_machine(py: TargetPython) -> str:
    normal_os = normalize_os(py)
    if normal_os == "linux":
        return {
            "aarch64": "aarch64",
            "x86": "i386",
            "x86_64": "x86_64",
        }.get(normalize_arch(py), "")
    elif normal_os == "darwin":
        return {
            "aarch64": "arm64",
            "x86_64": "x86_64",
        }.get(normalize_arch(py), "")
    elif normal_os == "windows":
        return {
            "x86": "i386",
            "x86_64": "x86_64",
        }.get(normalize_arch(py), "")

    return ""


def guess_platform_python_implementation(py: TargetPython) -> str:
    # See https://peps.python.org/pep-0425/#python-tag
    abbrev = py.implementation[:2]
    return {
        "py": "Python",
        "cp": "CPython",
        "ip": "IronPython",
        "pp": "PyPy",
        "jy": "Jython",
    }.get(abbrev, "")


def guess_platform_release(py: TargetPython) -> str:
    # Not possible from a TargetPython.
    return ""


def guess_platform_system(py: TargetPython) -> str:
    return {
        "linux": "Linux",
        "darwin": "Darwin",
        "windows": "Windows",
    }.get(normalize_os(py), "")


def guess_platform_version(py: TargetPython) -> str:
    # Not possible from a TargetPython.
    return ""


def guess_python_version(py: TargetPython) -> str:
    return ".".join((str(i) for i in py.py_version_info[:2]))


def guess_python_full_version(py: TargetPython) -> str:
    return ".".join((str(i) for i in py.py_version_info[:3]))


def guess_implementation_name(py: TargetPython) -> str:
    # See https://peps.python.org/pep-0425/#python-tag
    abbrev = py.implementation[:2]
    return {
        "py": "python",
        "cp": "cpython",
        "ip": "ironpython",
        "pp": "pypy",
        "jy": "jython",
    }.get(abbrev, "")


def guess_implementation_version(py: TargetPython) -> str:
    return guess_python_full_version(py)


def guess_environment_markers(py: TargetPython) -> Dict[str, str]:
    return {
        "os_name": guess_os_name(py),
        "sys_platform": guess_sys_platform(py),
        "platform_machine": guess_platform_machine(py),
        "platform_python_implementation": guess_platform_python_implementation(py),
        "platform_release": guess_platform_release(py),
        "platform_system": guess_platform_system(py),
        "platform_version": guess_platform_version(py),
        "python_version": guess_python_version(py),
        "python_full_version": guess_python_full_version(py),
        "implementation_name": guess_implementation_name(py),
        "implementation_version": guess_implementation_version(py),
    }
