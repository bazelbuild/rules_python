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

"""Utility class to inspect an extracted wheel directory"""

import email
import platform
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Set, Tuple, Union

import installer
from packaging.requirements import Requirement
from pip._vendor.packaging.utils import canonicalize_name


class OS(Enum):
    linux = 1
    osx = 2
    windows = 3
    darwin = osx
    win32 = windows

    @classmethod
    def interpreter(cls) -> "OS":
        "Return the interpreter operating system."
        return cls[sys.platform.lower()]

    def __str__(self) -> str:
        return self.name.lower()


class Arch(Enum):
    x86_64 = 1
    x86_32 = 2
    aarch64 = 3
    ppc = 4
    s390x = 5
    amd64 = x86_64
    arm64 = aarch64
    i386 = x86_32
    i686 = x86_32
    x86 = x86_32
    ppc64le = ppc

    @classmethod
    def interpreter(cls) -> "OS":
        "Return the currently running interpreter architecture."
        # FIXME @aignas 2023-12-13: Hermetic toolchain on Windows 3.11.6
        # is returning an empty string here, so lets default to x86_64
        return cls[platform.machine().lower() or "x86_64"]

    def __str__(self) -> str:
        return self.name.lower()


def _as_int(value: Optional[Union[OS, Arch]]) -> int:
    """Convert one of the enums above to an int for easier sorting algorithms.

    Args:
        value: The value of an enum or None.

    Returns:
        -1 if we get None, otherwise, the numeric value of the given enum.
    """
    if value is None:
        return -1

    return int(value.value)


def host_interpreter_minor_version() -> int:
    return sys.version_info.minor


@dataclass(frozen=True)
class Platform:
    os: Optional[OS] = None
    arch: Optional[Arch] = None
    minor_version: Optional[int] = None

    def __post_init__(self):
        if not self.os and not self.arch and not self.minor_version:
            raise ValueError(
                "At least one of os, arch, minor_version must be specified"
            )

    @classmethod
    def all(
        cls,
        want_os: Optional[OS] = None,
        minor_version: Optional[int] = None,
    ) -> List["Platform"]:
        return sorted(
            [
                cls(os=os, arch=arch, minor_version=minor_version)
                for os in OS
                for arch in Arch
                if not want_os or want_os == os
            ]
        )

    @classmethod
    def host(cls) -> List["Platform"]:
        """Use the Python interpreter to detect the platform.

        We extract `os` from sys.platform and `arch` from platform.machine

        Returns:
            A list of parsed values which makes the signature the same as
            `Platform.all` and `Platform.from_string`.
        """
        return [cls(os=OS.interpreter(), arch=Arch.interpreter())]

    def all_specializations(self) -> Iterator["Platform"]:
        """Return the platform itself and all its unambiguous specializations.

        For more info about specializations see
        https://bazel.build/docs/configurable-attributes
        """
        yield self
        if self.arch is None:
            for arch in Arch:
                yield Platform(os=self.os, arch=arch, minor_version=self.minor_version)
        if self.os is None:
            for os in OS:
                yield Platform(os=os, arch=self.arch, minor_version=self.minor_version)
        if self.arch is None and self.os is None:
            for os in OS:
                for arch in Arch:
                    yield Platform(os=os, arch=arch, minor_version=self.minor_version)

    def __lt__(self, other: Any) -> bool:
        """Add a comparison method, so that `sorted` returns the most specialized platforms first."""
        if not isinstance(other, Platform) or other is None:
            raise ValueError(f"cannot compare {other} with Platform")

        self_arch, self_os = _as_int(self.arch), _as_int(self.os)
        other_arch, other_os = _as_int(other.arch), _as_int(other.os)

        if self_os == other_os:
            return self_arch < other_arch
        else:
            return self_os < other_os

    def __str__(self) -> str:
        if self.minor_version is None:
            assert (
                self.os is not None
            ), f"if minor_version is None, OS must be specified, got {repr(self)}"
            if self.arch is None:
                return f"@platforms//os:{self.os}"
            else:
                return f"{self.os}_{self.arch}"

        if self.arch is None and self.os is None:
            return f"@//python/config_settings:is_python_3.{self.minor_version}"

        if self.arch is None:
            return f"cp3{self.minor_version}_{self.os}_anyarch"

        if self.os is None:
            return f"cp3{self.minor_version}_anyos_{self.arch}"

        return f"cp3{self.minor_version}_{self.os}_{self.arch}"

    @classmethod
    def from_string(cls, platform: Union[str, List[str]]) -> List["Platform"]:
        """Parse a string and return a list of platforms"""
        platform = [platform] if isinstance(platform, str) else list(platform)
        ret = set()
        for p in platform:
            if p == "host":
                ret.update(cls.host())
                continue

            abi, _, tail = p.partition("_")
            if not abi.startswith("cp"):
                # The first item is not an abi
                tail = p
                abi = ""
            os, _, arch = tail.partition("_")
            arch = arch or "*"

            minor_version = int(abi[len("cp3") :]) if abi else None

            if arch != "*":
                ret.add(
                    cls(
                        os=OS[os] if os != "*" else None,
                        arch=Arch[arch],
                        minor_version=minor_version,
                    )
                )
            else:
                ret.update(
                    cls.all(
                        want_os=OS[os] if os != "*" else None,
                        minor_version=minor_version,
                    )
                )

        return sorted(ret)

    # NOTE @aignas 2023-12-05: below is the minimum number of accessors that are defined in
    # https://peps.python.org/pep-0496/ to make rules_python generate dependencies.
    #
    # WARNING: It may not work in cases where the python implementation is different between
    # different platforms.

    # derived from OS
    @property
    def os_name(self) -> str:
        if self.os == OS.linux or self.os == OS.osx:
            return "posix"
        elif self.os == OS.windows:
            return "nt"
        else:
            return ""

    @property
    def sys_platform(self) -> str:
        if self.os == OS.linux:
            return "linux"
        elif self.os == OS.osx:
            return "darwin"
        elif self.os == OS.windows:
            return "win32"
        else:
            return ""

    @property
    def platform_system(self) -> str:
        if self.os == OS.linux:
            return "Linux"
        elif self.os == OS.osx:
            return "Darwin"
        elif self.os == OS.windows:
            return "Windows"

    # derived from OS and Arch
    @property
    def platform_machine(self) -> str:
        """Guess the target 'platform_machine' marker.

        NOTE @aignas 2023-12-05: this may not work on really new systems, like
        Windows if they define the platform markers in a different way.
        """
        if self.arch == Arch.x86_64:
            return "x86_64"
        elif self.arch == Arch.x86_32 and self.os != OS.osx:
            return "i386"
        elif self.arch == Arch.x86_32:
            return ""
        elif self.arch == Arch.aarch64 and self.os == OS.linux:
            return "aarch64"
        elif self.arch == Arch.aarch64:
            # Assuming that OSX and Windows use this one since the precedent is set here:
            # https://github.com/cgohlke/win_arm64-wheels
            return "arm64"
        elif self.os != OS.linux:
            return ""
        elif self.arch == Arch.ppc64le:
            return "ppc64le"
        elif self.arch == Arch.s390x:
            return "s390x"
        else:
            return ""

    def env_markers(self, extra: str) -> Dict[str, str]:
        # If it is None, use the host version
        minor_version = self.minor_version or host_interpreter_minor_version()

        return {
            "extra": extra,
            "os_name": self.os_name,
            "sys_platform": self.sys_platform,
            "platform_machine": self.platform_machine,
            "platform_system": self.platform_system,
            "platform_release": "",  # unset
            "platform_version": "",  # unset
            "python_version": f"3.{minor_version}",
            # FIXME @aignas 2024-01-14: is putting zero last a good idea? Maybe we should
            # use `20` or something else to avoid having weird issues where the full version is used for
            # matching and the author decides to only support 3.y.5 upwards.
            "implementation_version": f"3.{minor_version}.0",
            "python_full_version": f"3.{minor_version}.0",
            # we assume that the following are the same as the interpreter used to setup the deps:
            # "implementation_name": "cpython"
            # "platform_python_implementation: "CPython",
        }


@dataclass(frozen=True)
class FrozenDeps:
    deps: List[str]
    deps_select: Dict[str, List[str]]


class Deps:
    """Deps is a dependency builder that has a build() method to return FrozenDeps."""

    def __init__(
        self,
        name: str,
        requires_dist: List[str],
        *,
        extras: Optional[Set[str]] = None,
        platforms: Optional[Set[Platform]] = None,
    ):
        """Create a new instance and parse the requires_dist

        Args:
            name (str): The name of the whl distribution
            requires_dist (list[Str]): The Requires-Dist from the METADATA of the whl
                distribution.
            extras (set[str], optional): The list of requested extras, defaults to None.
            platforms (set[Platform], optional): The list of target platforms, defaults to
                None. If the list of platforms has multiple `minor_version` values, it
                will change the code to generate the select statements using
                `@rules_python//python/config_settings:is_python_3.y` conditions.
        """
        self.name: str = Deps._normalize(name)
        self._platforms: Set[Platform] = platforms or set()
        self._target_versions = {p.minor_version for p in platforms or {}}
        self._add_version_select = platforms and len(self._target_versions) > 2
        if None in self._target_versions and len(self._target_versions) > 2:
            raise ValueError(
                f"all python versions need to be specified explicitly, got: {platforms}"
            )

        # Sort so that the dictionary order in the FrozenDeps is deterministic
        # without the final sort because Python retains insertion order. That way
        # the sorting by platform is limited within the Platform class itself and
        # the unit-tests for the Deps can be simpler.
        reqs = sorted(
            (Requirement(wheel_req) for wheel_req in requires_dist),
            key=lambda x: f"{x.name}:{sorted(x.extras)}",
        )

        want_extras = self._resolve_extras(reqs, extras)

        # Then add all of the requirements in order
        self._deps: Set[str] = set()
        self._select: Dict[Platform, Set[str]] = defaultdict(set)
        for req in reqs:
            self._add_req(req, want_extras)

    def _add(self, dep: str, platform: Optional[Platform]):
        dep = Deps._normalize(dep)

        # Self-edges are processed in _resolve_extras
        if dep == self.name:
            return

        if not platform:
            self._deps.add(dep)
            return

        # Add the platform-specific dep
        self._select[platform].add(dep)

        # Add the dep to specializations of the given platform if they
        # exist in the select statement.
        for p in platform.all_specializations():
            if p not in self._select:
                continue

            self._select[p].add(dep)

        if len(self._select[platform]) == 1:
            # We are adding a new item to the select and we need to ensure that
            # existing dependencies from less specialized platforms are propagated
            # to the newly added dependency set.
            for p, deps in self._select.items():
                # Check if the existing platform overlaps with the given platform
                if p == platform or platform not in p.all_specializations():
                    continue

                self._select[platform].update(self._select[p])

    def _maybe_add_common_dep(self, dep):
        if len(self._target_versions) < 2:
            return

        platforms = [Platform(minor_version=v) for v in self._target_versions]

        # If the dep is targeting all target python versions, lets add it to
        # the common dependency list to simplify the select statements.
        for p in platforms:
            if p not in self._select:
                return

            if dep not in self._select[p]:
                return

        # All of the python version-specific branches have the dep, so lets add
        # it to the common deps.
        self._deps.add(dep)
        for p in platforms:
            self._select[p].remove(dep)
            if not self._select[p]:
                self._select.pop(p)

    @staticmethod
    def _normalize(name: str) -> str:
        return re.sub(r"[-_.]+", "_", name).lower()

    def _resolve_extras(
        self, reqs: List[Requirement], extras: Optional[Set[str]]
    ) -> Set[str]:
        """Resolve extras which are due to depending on self[some_other_extra].

        Some packages may have cyclic dependencies resulting from extras being used, one example is
        `etils`, where we have one set of extras as aliases for other extras
        and we have an extra called 'all' that includes all other extras.

        Example: github.com/google/etils/blob/a0b71032095db14acf6b33516bca6d885fe09e35/pyproject.toml#L32.

        When the `requirements.txt` is generated by `pip-tools`, then it is likely that
        this step is not needed, but for other `requirements.txt` files this may be useful.

        NOTE @aignas 2023-12-08: the extra resolution is not platform dependent,
        but in order for it to become platform dependent we would have to have
        separate targets for each extra in extras.
        """

        # Resolve any extra extras due to self-edges, empty string means no
        # extras The empty string in the set is just a way to make the handling
        # of no extras and a single extra easier and having a set of {"", "foo"}
        # is equivalent to having {"foo"}.
        extras = extras or {""}

        self_reqs = []
        for req in reqs:
            if Deps._normalize(req.name) != self.name:
                continue

            if req.marker is None:
                # I am pretty sure we cannot reach this code as it does not
                # make sense to specify packages in this way, but since it is
                # easy to handle, lets do it.
                #
                # TODO @aignas 2023-12-08: add a test
                extras = extras | req.extras
            else:
                # process these in a separate loop
                self_reqs.append(req)

        # A double loop is not strictly optimal, but always correct without recursion
        for req in self_reqs:
            if any(req.marker.evaluate({"extra": extra}) for extra in extras):
                extras = extras | req.extras
            else:
                continue

            # Iterate through all packages to ensure that we include all of the extras from previously
            # visited packages.
            for req_ in self_reqs:
                if any(req_.marker.evaluate({"extra": extra}) for extra in extras):
                    extras = extras | req_.extras

        return extras

    def _add_req(self, req: Requirement, extras: Set[str]) -> None:
        if req.marker is None:
            self._add(req.name, None)
            return

        marker_str = str(req.marker)

        if not self._platforms:
            if any(req.marker.evaluate({"extra": extra}) for extra in extras):
                self._add(req.name, None)
            return

        # NOTE @aignas 2023-12-08: in order to have reasonable select statements
        # we do have to have some parsing of the markers, so it begs the question
        # if packaging should be reimplemented in Starlark to have the best solution
        # for now we will implement it in Python and see what the best parsing result
        # can be before making this decision.
        match_os = any(
            tag in marker_str
            for tag in [
                "os_name",
                "sys_platform",
                "platform_system",
            ]
        )
        match_arch = "platform_machine" in marker_str
        match_version = "version" in marker_str

        if not (match_os or match_arch or match_version):
            if any(req.marker.evaluate({"extra": extra}) for extra in extras):
                self._add(req.name, None)
            return

        for plat in self._platforms:
            if not any(
                req.marker.evaluate(plat.env_markers(extra)) for extra in extras
            ):
                continue

            if match_arch:
                self._add(req.name, plat)
            elif match_os and self._add_version_select:
                self._add(req.name, Platform(plat.os, minor_version=plat.minor_version))
            elif match_os:
                self._add(req.name, Platform(plat.os))
            elif match_version and self._add_version_select:
                self._add(req.name, Platform(minor_version=plat.minor_version))
            elif match_version:
                self._add(req.name, None)

        # Merge to common if possible after processing all platforms
        self._maybe_add_common_dep(req.name)

    def build(self) -> FrozenDeps:
        return FrozenDeps(
            deps=sorted(self._deps),
            deps_select={str(p): sorted(deps) for p, deps in self._select.items()},
        )


class Wheel:
    """Representation of the compressed .whl file"""

    def __init__(self, path: Path):
        self._path = path

    @property
    def path(self) -> str:
        return self._path

    @property
    def name(self) -> str:
        # TODO Also available as installer.sources.WheelSource.distribution
        name = str(self.metadata["Name"])
        return canonicalize_name(name)

    @property
    def metadata(self) -> email.message.Message:
        with installer.sources.WheelFile.open(self.path) as wheel_source:
            metadata_contents = wheel_source.read_dist_info("METADATA")
            metadata = installer.utils.parse_metadata_file(metadata_contents)
        return metadata

    @property
    def version(self) -> str:
        # TODO Also available as installer.sources.WheelSource.version
        return str(self.metadata["Version"])

    def entry_points(self) -> Dict[str, Tuple[str, str]]:
        """Returns the entrypoints defined in the current wheel

        See https://packaging.python.org/specifications/entry-points/ for more info

        Returns:
            Dict[str, Tuple[str, str]]: A mapping of the entry point's name to it's module and attribute
        """
        with installer.sources.WheelFile.open(self.path) as wheel_source:
            if "entry_points.txt" not in wheel_source.dist_info_filenames:
                return dict()

            entry_points_mapping = dict()
            entry_points_contents = wheel_source.read_dist_info("entry_points.txt")
            entry_points = installer.utils.parse_entrypoints(entry_points_contents)
            for script, module, attribute, script_section in entry_points:
                if script_section == "console":
                    entry_points_mapping[script] = (module, attribute)

            return entry_points_mapping

    def dependencies(
        self,
        extras_requested: Set[str] = None,
        platforms: Optional[Set[Platform]] = None,
    ) -> FrozenDeps:
        return Deps(
            self.name,
            extras=extras_requested,
            platforms=platforms,
            requires_dist=self.metadata.get_all("Requires-Dist", []),
        ).build()

    def unzip(self, directory: str) -> None:
        installation_schemes = {
            "purelib": "/",
            "platlib": "/",
            "headers": "/include",
            "scripts": "/bin",
            "data": "/data",
        }
        destination = installer.destinations.SchemeDictionaryDestination(
            installation_schemes,
            # TODO Should entry_point scripts also be handled by installer rather than custom code?
            interpreter="/dev/null",
            script_kind="posix",
            destdir=directory,
            bytecode_optimization_levels=[],
        )

        with installer.sources.WheelFile.open(self.path) as wheel_source:
            installer.install(
                source=wheel_source,
                destination=destination,
                additional_metadata={
                    "INSTALLER": b"https://github.com/bazelbuild/rules_python",
                },
            )
