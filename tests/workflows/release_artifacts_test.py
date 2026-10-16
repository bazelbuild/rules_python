"""Tests for release artifact manifest snippet generation and merging."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

from python.runfiles import runfiles


def _rlocation(relpath: str) -> Path:
    rf = runfiles.CreateOrRaise()
    path = rf.Rlocation(relpath)
    assert path is not None, f"Could not find runfile: {relpath}"
    return Path(path)


def test_prepare_and_merge_release_files(tmp_path: Path):
    prepare_script = _rlocation(
        "rules_python/dev/release_artifacts/generate_tool_manifest_snippet.py"
    )
    merge_script = _rlocation(
        "rules_python/dev/release_artifacts/merge_manifest_snippets.py"
    )

    tools_dir = tmp_path / "release-tools"
    tools_dir.mkdir(parents=True)
    snippets_dir = tmp_path / "manifest-snippets"
    manifest_file = tmp_path / "tools_manifest.json"

    linux_bin = tools_dir / "exe_zip_maker-x86_64-unknown-linux-gnu"
    linux_bin.write_bytes(b"linux-binary-contents")
    linux_sha = hashlib.sha256(b"linux-binary-contents").hexdigest()

    win_bin = tools_dir / "exe_zip_maker-x86_64-pc-windows-msvc.exe"
    win_bin.write_bytes(b"windows-binary-contents")
    win_sha = hashlib.sha256(b"windows-binary-contents").hexdigest()

    mac_bin = tools_dir / "exe_zip_maker-aarch64-apple-darwin"
    mac_bin.write_bytes(b"mac-binary-contents")
    mac_sha = hashlib.sha256(b"mac-binary-contents").hexdigest()

    subprocess.run(
        [
            str(prepare_script),
            "2.4.0",
            str(tools_dir),
            str(snippets_dir),
            "bazel-contrib/rules_python",
        ],
        check=True,
    )

    subprocess.run(
        [str(merge_script), str(snippets_dir), str(manifest_file)],
        check=True,
    )

    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    assert manifest == {
        "tools": {
            "exe_zip_maker": [
                {
                    "exec_compatible_with": [
                        "@platforms//cpu:aarch64",
                        "@platforms//os:macos",
                    ],
                    "filename": "exe_zip_maker-aarch64-apple-darwin",
                    "sha256": mac_sha,
                    "urls": [
                        "https://github.com/bazel-contrib/rules_python/releases/download/2.4.0/exe_zip_maker-aarch64-apple-darwin"
                    ],
                },
                {
                    "exec_compatible_with": [
                        "@platforms//cpu:x86_64",
                        "@platforms//os:windows",
                    ],
                    "filename": "exe_zip_maker-x86_64-pc-windows-msvc.exe",
                    "sha256": win_sha,
                    "urls": [
                        "https://github.com/bazel-contrib/rules_python/releases/download/2.4.0/exe_zip_maker-x86_64-pc-windows-msvc.exe"
                    ],
                },
                {
                    "exec_compatible_with": [
                        "@platforms//cpu:x86_64",
                        "@platforms//os:linux",
                    ],
                    "filename": "exe_zip_maker-x86_64-unknown-linux-gnu",
                    "sha256": linux_sha,
                    "urls": [
                        "https://github.com/bazel-contrib/rules_python/releases/download/2.4.0/exe_zip_maker-x86_64-unknown-linux-gnu"
                    ],
                },
            ]
        }
    }


def test_prepare_and_merge_when_no_artifacts(tmp_path: Path):
    prepare_script = _rlocation(
        "rules_python/dev/release_artifacts/generate_tool_manifest_snippet.py"
    )
    merge_script = _rlocation(
        "rules_python/dev/release_artifacts/merge_manifest_snippets.py"
    )

    tools_dir = tmp_path / "missing-release-tools"
    snippets_dir = tmp_path / "manifest-snippets"
    manifest_file = tmp_path / "tools_manifest.json"

    subprocess.run(
        [
            str(prepare_script),
            "2.4.0",
            str(tools_dir),
            str(snippets_dir),
        ],
        check=True,
    )
    assert list(snippets_dir.iterdir()) == []

    subprocess.run(
        [str(merge_script), str(snippets_dir), str(manifest_file)],
        check=True,
    )
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    assert manifest == {"tools": {}}
