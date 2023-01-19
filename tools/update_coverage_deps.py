#!/usr/bin/python3 -B
"""A small script to update bazel files within the repo.

We are not running this with 'bazel run' to keep the dependencies minimal
"""

# NOTE @aignas 2023-01-09: We should only depend on core Python 3 packages.
import argparse
import difflib
import json
import pathlib
import sys
import textwrap
from dataclasses import dataclass
from typing import Any
from urllib import request

# This should be kept in sync with //python:versions.bzl
_supported_platforms = {
    # Windows is unsupported right now
    # "win_amd64": "x86_64-pc-windows-msvc",
    "manylinux2014_x86_64": "x86_64-unknown-linux-gnu",
    "manylinux2014_aarch64": "aarch64-unknown-linux-gnu",
    "macosx_11_0_arm64": "aarch64-apple-darwin",
    "macosx_10_9_x86_64": "x86_64-apple-darwin",
}


@dataclass
class Dep:
    name: str
    platform: str
    python: str
    url: str
    sha256: str

    @property
    def repo_name(self):
        return f"pypi__{self.name}_{self.python}_{self.platform}"

    def __repr__(self):
        return "\n".join(
            [
                "(",
                f'    "{self.python}",',
                f'    "{self.url}",',
                f'    "{self.sha256}",',
                f'    "{self.platform}",',
                ")",
            ]
        )


@dataclass
class Deps:
    deps: list[Dep]

    def __repr__(self):
        inner = textwrap.indent(
            ",\n".join([f"{repr(d)}" for d in self.deps]),
            prefix="    ",
        )
        return "[\n{},\n]".format(inner)


def _get_platforms(filename: str, name: str, version: str, python_version: str):
    return filename[
        len(f"{name}-{version}-{python_version}-{python_version}-") : -len(".whl")
    ].split(".")


def _map(
    name: str,
    filename: str,
    python_version: str,
    url: str,
    digests: list,
    platform: str,
    **kwargs: Any,
):
    if platform not in _supported_platforms:
        return None

    return Dep(
        name=name,
        platform=_supported_platforms[platform],
        python=python_version,
        url=url,
        sha256=digests["sha256"],
    )


def _writelines(path: pathlib.Path, lines: list[str]):
    with open(path, "w") as f:
        f.writelines(lines)


def _difflines(path: pathlib.Path, lines: list[str]):
    with open(path) as f:
        input = f.readlines()

    rules_python = pathlib.Path(__file__).parent.parent
    p = path.relative_to(rules_python)

    print(f"Diff of the changes that would be made to '{p}':")
    for line in difflib.unified_diff(
        input,
        lines,
        fromfile=f"a/{p}",
        tofile=f"b/{p}",
    ):
        print(line, end="")

    # Add an empty line at the end of the diff
    print()


def _update_file(
    path: pathlib.Path,
    snippet: str,
    start_marker: str,
    end_marker: str,
    dry_run: bool = True,
):
    with open(path) as f:
        input = f.readlines()

    out = []
    skip = False
    for line in input:
        if skip:
            if not line.startswith(end_marker):
                continue

            skip = False

        out.append(line)

        if not line.startswith(start_marker):
            continue

        skip = True
        out.extend([f"{line}\n" for line in snippet.splitlines()])

    if dry_run:
        _difflines(path, out)
    else:
        _writelines(path, out)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument(
        "--name",
        default="coverage",
        type=str,
        help="The name of the package",
    )
    parser.add_argument(
        "version",
        type=str,
        help="The version of the package to download",
    )
    parser.add_argument(
        "--py",
        nargs="+",
        type=str,
        default=["cp38", "cp39", "cp310", "cp311"],
        help="Supported python versions",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Wether to write to files",
    )
    return parser.parse_args()


def main():
    args = _parse_args()

    api_url = f"https://pypi.python.org/pypi/{args.name}/{args.version}/json"
    req = request.Request(api_url)
    with request.urlopen(req) as response:
        data = json.loads(response.read().decode("utf-8"))

    urls = []
    for u in data["urls"]:
        if u["yanked"]:
            continue

        if not u["filename"].endswith(".whl"):
            continue

        if u["python_version"] not in args.py:
            continue

        if f'_{u["python_version"]}m_' in u["filename"]:
            continue

        platforms = _get_platforms(
            u["filename"],
            args.name,
            args.version,
            u["python_version"],
        )

        result = [_map(name=args.name, platform=p, **u) for p in platforms]
        urls.extend(filter(None, result))

    urls.sort(key=lambda x: f"{x.python}_{x.platform}")

    rules_python = pathlib.Path(__file__).parent.parent

    # Update the coverage_deps, which are used to register deps
    _update_file(
        path=rules_python / "python" / "private" / "coverage_deps.bzl",
        snippet=f"_coverage_deps = {repr(Deps(urls))}\n",
        start_marker="#START: managed by update_coverage_deps.py script",
        end_marker="#END: managed by update_coverage_deps.py script",
        dry_run=args.dry_run,
    )

    # Update the MODULE.bazel, which needs to expose the dependencies to the toolchain
    # repositories
    _update_file(
        path=rules_python / "MODULE.bazel",
        snippet="".join(sorted([f'    "{u.repo_name}",\n' for u in urls])),
        start_marker="    # coverage_deps managed by running",
        end_marker=")",
        dry_run=args.dry_run,
    )

    return


if __name__ == "__main__":
    main()
