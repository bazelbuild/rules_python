#!/usr/bin/env python3
"""Generates an artifacts_manifest.json file for built release binaries."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

_CPU_TO_CONSTRAINT = {
    "aarch64": "@platforms//cpu:aarch64",
    "armv7": "@platforms//cpu:armv7",
    "i686": "@platforms//cpu:x86_32",
    "powerpc64le": "@platforms//cpu:ppc64le",
    "riscv64gc": "@platforms//cpu:riscv64",
    "x86_64": "@platforms//cpu:x86_64",
}

_FILENAME_RE = re.compile(r"^(.+)-((?:" + "|".join(_CPU_TO_CONSTRAINT) + r")-.+)$")


def _cpu_constraint(triple: str) -> str:
    cpu = triple.split("-", 1)[0]
    if cpu in _CPU_TO_CONSTRAINT:
        return _CPU_TO_CONSTRAINT[cpu]
    raise ValueError(f"Unsupported CPU in triple: {triple}")


def _os_constraint(triple: str) -> str:
    if triple.endswith("-apple-darwin"):
        return "@platforms//os:macos"
    if "-pc-windows-" in triple:
        return "@platforms//os:windows"
    if "-linux-" in triple:
        return "@platforms//os:linux"
    raise ValueError(f"Unsupported OS in triple: {triple}")


def generate_manifest(
    tag: str,
    tools_dir: Path,
    repo: str,
) -> dict[str, Any]:
    tools: dict[str, list[dict[str, Any]]] = {}
    for file_path in sorted(tools_dir.iterdir()):
        filename = file_path.name
        base = filename.removesuffix(".exe")
        match = _FILENAME_RE.match(base)
        if not match:
            raise ValueError(f"Cannot parse tool and triple from filename: {filename}")
        tool, triple = match.group(1), match.group(2)

        cpu = _cpu_constraint(triple)
        os_constraint = _os_constraint(triple)
        sha256 = hashlib.sha256(file_path.read_bytes()).hexdigest()
        url = f"https://github.com/{repo}/releases/download/{tag}/{filename}"

        tools.setdefault(tool, []).append(
            {
                "exec_compatible_with": [cpu, os_constraint],
                "filename": filename,
                "sha256": sha256,
                "urls": [url],
            }
        )

    for entries in tools.values():
        entries.sort(key=lambda entry: entry["filename"])

    return {"tools": dict(sorted(tools.items()))}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="Release tag name (e.g. 2.4.0).")
    parser.add_argument(
        "tools_dir",
        type=Path,
        help="Directory containing built <tool>-<triple>[.exe] files.",
    )
    parser.add_argument(
        "output_file",
        type=Path,
        help="Path to the artifacts_manifest.json file to write.",
    )
    parser.add_argument(
        "repo",
        nargs="?",
        default=os.environ.get("GITHUB_REPOSITORY") or "bazel-contrib/rules_python",
        help="GitHub owner/repository name.",
    )
    args = parser.parse_args(argv)
    manifest = generate_manifest(args.tag, args.tools_dir, args.repo)
    args.output_file.parent.mkdir(parents=True, exist_ok=True)
    args.output_file.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
