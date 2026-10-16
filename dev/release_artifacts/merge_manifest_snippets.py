#!/usr/bin/env python3
"""Merges JSON manifest snippets into a single tools_manifest.json file."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def merge_snippets(snippets_dir: Path) -> dict[str, Any]:
    tools: dict[str, list[dict[str, Any]]] = {}
    if snippets_dir.is_dir():
        for snippet_path in sorted(snippets_dir.glob("*.json")):
            data = json.loads(snippet_path.read_text(encoding="utf-8"))
            for tool, entries in data.get("tools", {}).items():
                tools.setdefault(tool, []).extend(entries)

    for tool, entries in tools.items():
        entries.sort(key=lambda entry: entry["filename"])

    return {"tools": dict(sorted(tools.items()))}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "snippets_dir",
        type=Path,
        help="Directory containing per-binary *.json manifest snippets.",
    )
    parser.add_argument(
        "output_file",
        type=Path,
        help="Path to the merged tools_manifest.json file to write.",
    )
    args = parser.parse_args(argv)

    manifest = merge_snippets(args.snippets_dir)
    args.output_file.parent.mkdir(parents=True, exist_ok=True)
    args.output_file.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
