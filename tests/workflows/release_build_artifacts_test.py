"""Tests for the release_build_artifacts.yaml workflow."""

from __future__ import annotations

import re

import yaml

from python.runfiles import runfiles


def test_matrix_matches_dev_platforms():
    """Each platform in dev/platforms has one matrix job, and vice versa.

    Otherwise, a platform isn't built or is built twice, or a job fails because
    its platform is missing.
    """
    root = runfiles.CreateOrRaise().root() / "rules_python"
    workflow_path = root / ".github/workflows/release_build_artifacts.yaml"
    workflow = yaml.safe_load(workflow_path.read_text(encoding="utf-8"))
    triples = [
        entry["triple"]
        for entry in workflow["jobs"]["build"]["strategy"]["matrix"]["include"]
    ]
    build_file = (root / "dev/platforms/BUILD.bazel").read_text(encoding="utf-8")
    platforms = re.findall(r'^platform\(\s*name = "([^"]+)",', build_file, re.MULTILINE)

    assert platforms, "No platforms found in dev/platforms/BUILD.bazel"
    # Fail instead of missing a platform whose call doesn't start with its name,
    # e.g. because of a comment.
    calls = re.findall(r"^platform\(", build_file, re.MULTILINE)
    assert len(platforms) == len(calls), "Couldn't parse every platform's name"
    # Sets, so that failures list the triples that differ.
    assert set(triples) == set(platforms), "Matrix (left) vs. dev/platforms (right)"
    duplicates = sorted({triple for triple in triples if triples.count(triple) > 1})
    assert not duplicates, f"Triples with more than one job: {duplicates}"
