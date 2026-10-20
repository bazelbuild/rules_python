"""Tests for the .github/actions/setup-bazel composite action."""

from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

import yaml

from python.runfiles import runfiles


def _action_dir() -> Path:
    return runfiles.CreateOrRaise().root() / "rules_python/.github/actions/setup-bazel"


def _write_fake_bazel(bin_dir: Path, body: str) -> Path:
    bin_dir.mkdir(parents=True, exist_ok=True)
    fake_bazel = bin_dir / "bazel"
    fake_bazel.write_text(
        f"#!/usr/bin/env bash\nset -euo pipefail\n{body}\n", encoding="utf-8"
    )
    fake_bazel.chmod(0o755)
    return fake_bazel


def test_action_yaml_invokes_executable_download_script():
    """Verifies setup-bazel action.yaml runs download_bazel.sh and the script is +x."""
    action_dir = _action_dir()
    script = action_dir / "download_bazel.sh"
    assert script.is_file()
    assert bool(script.stat().st_mode & stat.S_IXUSR), (
        "download_bazel.sh must be executable"
    )

    action = yaml.safe_load((action_dir / "action.yaml").read_text(encoding="utf-8"))
    steps = action["runs"]["steps"]
    assert any("download_bazel.sh" in step.get("run", "") for step in steps)


def test_action_yaml_enables_buildbuddy_only_on_linux():
    """Verifies setup-bazel action.yaml only enables BuildBuddy on Linux."""
    action = yaml.safe_load((_action_dir() / "action.yaml").read_text(encoding="utf-8"))
    steps = action["runs"]["steps"]
    setup_step = next(s for s in steps if s.get("name") == "Setup Bazel")
    assert "runner.os == 'Linux'" in setup_step["with"]["bazelrc"]
    secret_step = next(
        s for s in steps if s.get("name") == "Write secret to user.bazelrc"
    )
    assert "runner.os == 'Linux'" in secret_step["if"]


def test_download_bazel_succeeds_first_try(tmp_path: Path):
    """Verifies download_bazel.sh succeeds without warnings when bazel --version succeeds."""
    script = _action_dir() / "download_bazel.sh"
    calls_file = tmp_path / "calls.txt"
    _write_fake_bazel(
        tmp_path / "bin",
        f'echo "$@" >> "{calls_file}"\necho "bazel 9.1.1"\n',
    )

    env = os.environ.copy()
    env["PATH"] = f"{tmp_path / 'bin'}:{env.get('PATH', '')}"
    env["HOME"] = str(tmp_path / "home")

    result = subprocess.run(
        [str(script)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
    assert calls_file.read_text(encoding="utf-8").splitlines() == ["--version"]
    assert "::warning::" not in result.stdout
    assert "::error::" not in result.stdout


def test_download_bazel_retries_transient_failure(tmp_path: Path):
    """Verifies download_bazel.sh retries transient failures and succeeds."""
    script = _action_dir() / "download_bazel.sh"
    calls_file = tmp_path / "calls.txt"
    _write_fake_bazel(
        tmp_path / "bin",
        f"""
echo "$@" >> "{calls_file}"
count=$(wc -l < "{calls_file}")
if (( count < 3 )); then
  echo "could not download Bazel: stream error: INTERNAL_ERROR" >&2
  exit 1
fi
mkdir -p "$HOME/.cache/bazelisk/downloads"
echo "bazel 9.1.1"
""",
    )

    home = tmp_path / "home"
    env = os.environ.copy()
    env["PATH"] = f"{tmp_path / 'bin'}:{env.get('PATH', '')}"
    env["HOME"] = str(home)
    env["BAZEL_DOWNLOAD_INITIAL_DELAY"] = "0"

    result = subprocess.run(
        [str(script)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
    assert calls_file.read_text(encoding="utf-8").splitlines() == [
        "--version",
        "--version",
        "--version",
    ]
    assert "::warning::Failed to download Bazel (attempt 1/5)" in result.stdout
    assert "::warning::Failed to download Bazel (attempt 2/5)" in result.stdout
    assert (home / ".cache/bazelisk/downloads").is_dir()


def test_download_bazel_exhausts_retries_and_cleans_cache(tmp_path: Path):
    """Verifies download_bazel.sh cleans up partial cache dirs when all retries fail."""
    script = _action_dir() / "download_bazel.sh"
    calls_file = tmp_path / "calls.txt"
    _write_fake_bazel(
        tmp_path / "bin",
        f"""
echo "$@" >> "{calls_file}"
mkdir -p "$HOME/.cache/bazelisk/downloads/_tmp"
mkdir -p "$BAZELISK_HOME/downloads/_tmp"
exit 1
""",
    )

    home = tmp_path / "home"
    bazelisk_home = tmp_path / "bazelisk_home"
    env = os.environ.copy()
    env["PATH"] = f"{tmp_path / 'bin'}:{env.get('PATH', '')}"
    env["HOME"] = str(home)
    env["BAZELISK_HOME"] = str(bazelisk_home)
    env["BAZEL_DOWNLOAD_MAX_ATTEMPTS"] = "3"
    env["BAZEL_DOWNLOAD_INITIAL_DELAY"] = "0"

    result = subprocess.run(
        [str(script)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1
    assert len(calls_file.read_text(encoding="utf-8").splitlines()) == 3
    assert "::error::Failed to download Bazel after 3 attempts" in result.stdout
    assert not (home / ".cache/bazelisk").exists()
    assert not bazelisk_home.exists()
