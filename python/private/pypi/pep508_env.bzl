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

"""This module is for implementing PEP508 environment definition.
"""

load("//python/private:normalize_name.bzl", "normalize_name")
load(":pep508_evaluate.bzl", "evaluate")

_platform_machine_values = {
    "aarch64": "arm64",
    "ppc": "ppc64le",
    "s390x": "s390x",
    "x86_32": "i386",
    "x86_64": "x86_64",
}
_platform_system_values = {
    "linux": "Linux",
    "osx": "Darwin",
    "windows": "Windows",
}
_sys_platform_values = {
    "linux": "posix",
    "osx": "darwin",
    "windows": "win32",
}
_os_name_values = {
    "linux": "posix",
    "osx": "posix",
    "windows": "nt",
}

def env(target_platform):
    """Return an env target platform

    Args:
        target_platform: {type}`str` the target platform identifier, e.g.
            `cp33_linux_aarch64`

    Returns:
        A dict that can be used as `env` in the marker evaluation.
    """

    # TODO @aignas 2024-12-26: wire up the usage of the micro version
    minor, _, micro = target_platform.abi[3:].partition(".")
    micro = micro or "0"
    os = target_platform.os
    arch = target_platform.arch

    # TODO @aignas 2025-02-13: consider moving this into config settings.

    # This is split by topic
    return {
        "os_name": _os_name_values.get(os, ""),
        "platform_machine": "aarch64" if (os, arch) == ("linux", "aarch64") else _platform_machine_values.get(arch, ""),
        "platform_system": _platform_system_values.get(os, ""),
        "sys_platform": _sys_platform_values.get(os, ""),
    } | {
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
        "platform_release": "",
        "platform_version": "",
    } | {
        "implementation_version": "3.{}.{}".format(minor, micro),
        "python_full_version": "3.{}.{}".format(minor, micro),
        "python_version": "3.{}".format(minor),
    }

def deps(name, *, requires_dist, platforms = [], python_version = None):
    """Parse the RequiresDist from wheel METADATA

    Args:
        name: {type}`str` the name of the wheel.
        requires_dist: {type}`list[str]` the list of RequiresDist lines from the
            METADATA file.
        platforms: {type}`list[str]` the list of target platform strings.
        python_version: {type}`str` the host python version.

    Returns:
        A struct with attributes:
        * deps: {type}`list[str]` dependencies to include unconditionally.
        * deps_select: {type}`dict[str, list[str]]` dependencies to include on particular
              subset of target platforms.
    """
    reqs = sorted(
        [_req(r) for r in requires_dist],
        key = lambda x: x.name,
    )
    deps = []
    deps_select = {}

    platforms = [
        _platform_from_str(_versioned_platform(p, python_version))
        for p in platforms
    ]
    for req in reqs:
        _add_req(deps, deps_select, req, platforms)

    return struct(
        deps = deps,
        deps_select = {
            _platform_str(p): deps
            for p, deps in deps_select.items()
        },
    )

def _versioned_platform(os_arch, python_version):
    if not python_version or os_arch.startswith("cp"):
        # This also has ABI
        return os_arch

    major, _, tail = python_version.partition(".")
    minor, _, _ = tail.partition(".")
    return "cp{}{}_{}".format(major, minor, os_arch)

def _req(requires_dist):
    requires, _, marker = requires_dist.partition(";")
    return struct(
        name = normalize_name(requires),
        marker = marker.strip(" "),
    )

def _add_req(deps, deps_select, req, platforms):
    if not req.marker:
        _add(deps, deps_select, req.name, None)
        return

    # NOTE @aignas 2023-12-08: in order to have reasonable select statements
    # we do have to have some parsing of the markers, so it begs the question
    # if packaging should be reimplemented in Starlark to have the best solution
    # for now we will implement it in Python and see what the best parsing result
    # can be before making this decision.
    match_os = len([
        tag
        for tag in [
            "os_name",
            "sys_platform",
            "platform_system",
        ]
        if tag in req.marker
    ]) > 0
    match_arch = "platform_machine" in req.marker

    if not (match_os or match_arch):
        _add(deps, deps_select, req.name, None)
        return

    for plat in platforms:
        if not evaluate(req.marker, env = env(plat)):
            continue

        if match_arch:
            _add(deps, deps_select, req.name, _platform(os = plat.os, arch = plat.arch))
        elif match_os:
            _add(deps, deps_select, req.name, _platform(os = plat.os))
        else:
            fail("TODO: {}, {}".format(req.marker, plat))

def _platform(*, abi = None, os = None, arch = None):
    return struct(
        abi = abi,
        os = os,
        arch = arch,
    )

def _platform_from_str(p):
    abi, _, p = p.partition("_")
    os, _, arch = p.partition("_")
    return _platform(abi = abi, os = os, arch = arch)

def _platform_str(self):
    if self.abi == None:
        if not self.os and not self.arch:
            return "//conditions:default"
        elif not self.arch:
            return "@platforms//os:{}".format(self.os)
        else:
            return "{}_{}".format(self.os, self.arch)

    minor_version = self.abi[3:]
    if self.arch == None and self.os == None:
        return "@//python/config_settings:is_python_3.{}".format(minor_version)

    return "cp3{}_{}_{}".format(
        minor_version,
        self.os or "anyos",
        self.arch or "anyarch",
    )

def _platform_specializations(self):
    specializations = []
    specializations.append(self)
    if self.arch == None:
        specializations.extend([
            _platform(os = self.os, arch = arch, abi = self.abi)
            for arch in _platform_machine_values
        ])
    if self.os == None:
        specializations.extend([
            _platform(os = os, arch = self.arch, abi = self.abi)
            for os in _platform_system_values
        ])
    return specializations

def _add(deps, deps_select, dep, platform):
    dep = normalize_name(dep)
    add_to = []

    if platform:
        # Add the platform-specific dep
        deps = deps_select.setdefault(platform, [])
        add_to.append(deps)
        if not deps:
            # We are adding a new item to the select and we need to ensure that
            # existing dependencies from less specialized platforms are propagated
            # to the newly added dependency set.
            for p, existing_deps in deps_select.items():
                # Check if the existing platform overlaps with the given platform
                if p == platform or platform not in _platform_specializations(p):
                    continue

                # Copy existing elements from the existing specializations.
                for d in existing_deps:
                    if d not in deps:
                        deps.append(d)

        for p in _platform_specializations(platform):
            if p not in deps_select:
                continue

            more_specialized_deps = deps_select.get(p, [])
            if dep not in more_specialized_deps:
                add_to.append(more_specialized_deps)
    else:
        add_to.append(deps)

    for deps in add_to:
        if dep not in deps:
            deps.append(dep)

#       if not self._platforms:
#           if any(req.marker.evaluate({"extra": extra}) for extra in extras):
#               self._add(req.name, None)
#           return

#       # NOTE @aignas 2023-12-08: in order to have reasonable select statements
#       # we do have to have some parsing of the markers, so it begs the question
#       # if packaging should be reimplemented in Starlark to have the best solution
#       # for now we will implement it in Python and see what the best parsing result
#       # can be before making this decision.
#       match_os = any(
#           tag in marker_str
#           for tag in [
#               "os_name",
#               "sys_platform",
#               "platform_system",
#           ]
#       )
#       match_arch = "platform_machine" in marker_str
#       match_version = "version" in marker_str

#       if not (match_os or match_arch or match_version):
#           if any(req.marker.evaluate({"extra": extra}) for extra in extras):
#               self._add(req.name, None)
#           return

#       for plat in self._platforms:
#           if not any(
#               req.marker.evaluate(plat.env_markers(extra)) for extra in extras
#           ):
#               continue

#           if match_arch and self._default_minor_version:
#               self._add(req.name, plat)
#               if plat.minor_version == self._default_minor_version:
#                   self._add(req.name, Platform(plat.os, plat.arch))
#           elif match_arch:
#               self._add(req.name, Platform(plat.os, plat.arch))
#           elif match_os and self._default_minor_version:
#               self._add(req.name, Platform(plat.os, minor_version=plat.minor_version))
#               if plat.minor_version == self._default_minor_version:
#                   self._add(req.name, Platform(plat.os))
#           elif match_os:
#               self._add(req.name, Platform(plat.os))
#           elif match_version and self._default_minor_version:
#               self._add(req.name, Platform(minor_version=plat.minor_version))
#               if plat.minor_version == self._default_minor_version:
#                   self._add(req.name, Platform())
#           elif match_version:
#               self._add(req.name, None)

#       # Merge to common if possible after processing all platforms
#       self._maybe_add_common_dep(req.name)

#       self.name: str = Deps._normalize(name)
#       self._platforms: Set[Platform] = platforms or set()
#       self._target_versions = {p.minor_version for p in platforms or {}}

#       self._default_minor_version = None
#       if platforms and len(self._target_versions) > 2:
#           # TODO @aignas 2024-06-23: enable this to be set via a CLI arg
#           # for being more explicit.
#           self._default_minor_version = host_interpreter_minor_version()

#       if None in self._target_versions and len(self._target_versions) > 2:
#           raise ValueError(
#               f"all python versions need to be specified explicitly, got: {platforms}"
#           )

#       # Sort so that the dictionary order in the FrozenDeps is deterministic
#       # without the final sort because Python retains insertion order. That way
#       # the sorting by platform is limited within the Platform class itself and
#       # the unit-tests for the Deps can be simpler.
#       reqs = sorted(
#           (Requirement(wheel_req) for wheel_req in requires_dist),
#           key=lambda x: f"{x.name}:{sorted(x.extras)}",
#       )

#       want_extras = self._resolve_extras(reqs, extras)

#       # Then add all of the requirements in order
#       self._deps: Set[str] = set()
#       self._select: Dict[Platform, Set[str]] = defaultdict(set)
#       for req in reqs:
#           self._add_req(req, want_extras)

#   def _add(self, dep: str, platform: Optional[Platform]):
#       dep = Deps._normalize(dep)

#       # Self-edges are processed in _resolve_extras
#       if dep == self.name:
#           return

#       if not platform:
#           self._deps.add(dep)

#           # If the dep is in the platform-specific list, remove it from the select.
#           pop_keys = []
#           for p, deps in self._select.items():
#               if dep not in deps:
#                   continue

#               deps.remove(dep)
#               if not deps:
#                   pop_keys.append(p)

#           for p in pop_keys:
#               self._select.pop(p)
#           return

#       if dep in self._deps:
#           # If the dep is already in the main dependency list, no need to add it in the
#           # platform-specific dependency list.
#           return

#       # Add the platform-specific dep
#       self._select[platform].add(dep)

#       # Add the dep to specializations of the given platform if they
#       # exist in the select statement.
#       for p in platform.all_specializations():
#           if p not in self._select:
#               continue

#           self._select[p].add(dep)

#       if len(self._select[platform]) == 1:
#           # We are adding a new item to the select and we need to ensure that
#           # existing dependencies from less specialized platforms are propagated
#           # to the newly added dependency set.
#           for p, deps in self._select.items():
#               # Check if the existing platform overlaps with the given platform
#               if p == platform or platform not in p.all_specializations():
#                   continue

#               self._select[platform].update(self._select[p])

#   def _maybe_add_common_dep(self, dep):
#       if len(self._target_versions) < 2:
#           return

#       platforms = [Platform()] + [
#           Platform(minor_version=v) for v in self._target_versions
#       ]

#       # If the dep is targeting all target python versions, lets add it to
#       # the common dependency list to simplify the select statements.
#       for p in platforms:
#           if p not in self._select:
#               return

#           if dep not in self._select[p]:
#               return

#       # All of the python version-specific branches have the dep, so lets add
#       # it to the common deps.
#       self._deps.add(dep)
#       for p in platforms:
#           self._select[p].remove(dep)
#           if not self._select[p]:
#               self._select.pop(p)

#   def _resolve_extras(
#       self, reqs: List[Requirement], extras: Optional[Set[str]]
#   ) -> Set[str]:
#       """Resolve extras which are due to depending on self[some_other_extra].

#       Some packages may have cyclic dependencies resulting from extras being used, one example is
#       `etils`, where we have one set of extras as aliases for other extras
#       and we have an extra called 'all' that includes all other extras.

#       Example: github.com/google/etils/blob/a0b71032095db14acf6b33516bca6d885fe09e35/pyproject.toml#L32.

#       When the `requirements.txt` is generated by `pip-tools`, then it is likely that
#       this step is not needed, but for other `requirements.txt` files this may be useful.

#       NOTE @aignas 2023-12-08: the extra resolution is not platform dependent,
#       but in order for it to become platform dependent we would have to have
#       separate targets for each extra in extras.
#       """

#       # Resolve any extra extras due to self-edges, empty string means no
#       # extras The empty string in the set is just a way to make the handling
#       # of no extras and a single extra easier and having a set of {"", "foo"}
#       # is equivalent to having {"foo"}.
#       extras = extras or {""}

#       self_reqs = []
#       for req in reqs:
#           if Deps._normalize(req.name) != self.name:
#               continue

#           if req.marker is None:
#               # I am pretty sure we cannot reach this code as it does not
#               # make sense to specify packages in this way, but since it is
#               # easy to handle, lets do it.
#               #
#               # TODO @aignas 2023-12-08: add a test
#               extras = extras | req.extras
#           else:
#               # process these in a separate loop
#               self_reqs.append(req)

#       # A double loop is not strictly optimal, but always correct without recursion
#       for req in self_reqs:
#           if any(req.marker.evaluate({"extra": extra}) for extra in extras):
#               extras = extras | req.extras
#           else:
#               continue

#           # Iterate through all packages to ensure that we include all of the extras from previously
#           # visited packages.
#           for req_ in self_reqs:
#               if any(req_.marker.evaluate({"extra": extra}) for extra in extras):
#                   extras = extras | req_.extras

#       return extras

#   def _add_req(self, req: Requirement, extras: Set[str]) -> None:
#       if req.marker is None:
#           self._add(req.name, None)
#           return

#       marker_str = str(req.marker)

#       if not self._platforms:
#           if any(req.marker.evaluate({"extra": extra}) for extra in extras):
#               self._add(req.name, None)
#           return

#       # NOTE @aignas 2023-12-08: in order to have reasonable select statements
#       # we do have to have some parsing of the markers, so it begs the question
#       # if packaging should be reimplemented in Starlark to have the best solution
#       # for now we will implement it in Python and see what the best parsing result
#       # can be before making this decision.
#       match_os = any(
#           tag in marker_str
#           for tag in [
#               "os_name",
#               "sys_platform",
#               "platform_system",
#           ]
#       )
#       match_arch = "platform_machine" in marker_str
#       match_version = "version" in marker_str

#       if not (match_os or match_arch or match_version):
#           if any(req.marker.evaluate({"extra": extra}) for extra in extras):
#               self._add(req.name, None)
#           return

#       for plat in self._platforms:
#           if not any(
#               req.marker.evaluate(plat.env_markers(extra)) for extra in extras
#           ):
#               continue

#           if match_arch and self._default_minor_version:
#               self._add(req.name, plat)
#               if plat.minor_version == self._default_minor_version:
#                   self._add(req.name, Platform(plat.os, plat.arch))
#           elif match_arch:
#               self._add(req.name, Platform(plat.os, plat.arch))
#           elif match_os and self._default_minor_version:
#               self._add(req.name, Platform(plat.os, minor_version=plat.minor_version))
#               if plat.minor_version == self._default_minor_version:
#                   self._add(req.name, Platform(plat.os))
#           elif match_os:
#               self._add(req.name, Platform(plat.os))
#           elif match_version and self._default_minor_version:
#               self._add(req.name, Platform(minor_version=plat.minor_version))
#               if plat.minor_version == self._default_minor_version:
#                   self._add(req.name, Platform())
#           elif match_version:
#               self._add(req.name, None)

#       # Merge to common if possible after processing all platforms
#       self._maybe_add_common_dep(req.name)

#   def build(self) -> FrozenDeps:
#       return FrozenDeps(
#           deps=sorted(self._deps),
#           deps_select={str(p): sorted(deps) for p, deps in self._select.items()},
#       )
