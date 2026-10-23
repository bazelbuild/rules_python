#!/usr/bin/env python3

import argparse
import json
import re
import subprocess
import sys
import time

DEFAULT_GH_REPO = "bazel-contrib/rules_python"
GH_ACTIONS_URL_RE = re.compile(
    r"github\.com/([^/]+/[^/]+)/actions/runs/(\d+)(?:/job/(\d+))?"
)


def check_cli(cmd_name, install_url):
    try:
        subprocess.run(
            [cmd_name, "--version"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        print(
            f"❌ Error: '{cmd_name}' CLI is not installed or not in PATH.",
            file=sys.stderr,
        )
        print(f"Please install it from {install_url}", file=sys.stderr)
        sys.exit(1)


def get_pr_checks(pr_number):
    check_cli("gh", "https://cli.github.com/")
    cmd = ["gh", "pr", "checks", str(pr_number), "--json", "name,link,state,bucket"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    out = res.stdout
    if "[" not in out:
        print(
            f"❌ Error fetching PR checks for PR #{pr_number}: {res.stderr}",
            file=sys.stderr,
        )
        sys.exit(1)
    json_str = out[out.find("[") : out.rfind("]") + 1]
    return json.loads(json_str)


def parse_github_actions_url(target):
    m = GH_ACTIONS_URL_RE.search(target)
    if m:
        return m.group(1), m.group(2), m.group(3)
    return None


def get_github_run_data(repo, run_id):
    cmd = [
        "gh",
        "run",
        "view",
        str(run_id),
        "--repo",
        repo,
        "--json",
        "status,conclusion,jobs",
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    out = res.stdout
    json_str = out[out.find("{") : out.rfind("}") + 1] if "{" in out else "{}"
    return json.loads(json_str)


def wait_for_github_run_completion(
    repo, run_id, job_id=None, poll_interval=15, max_attempts=60
):
    for attempt in range(max_attempts):
        try:
            data = get_github_run_data(repo, str(run_id))
        except Exception as e:
            print(
                f"⚠️ Warning: Could not inspect GitHub Actions run {run_id}: {e}",
                file=sys.stderr,
            )
            return None

        status = (data.get("status") or "").lower()
        jobs = data.get("jobs", [])

        if job_id is not None:
            active_job_ids = {str(j.get("databaseId")) for j in jobs}
            if str(job_id) not in active_job_ids:
                # The job ID from an earlier attempt is no longer in the active jobs
                # list, meaning a newer run_attempt is already queued/running/done.
                if status != "completed" or data.get("conclusion") == "success":
                    print(
                        f"ℹ️ GitHub Actions job {job_id} has already been superseded "
                        f"by a newer attempt in run {run_id} (status: {status})."
                    )
                    return data

        if status == "completed":
            return data

        print(
            f"⏳ GitHub Actions run {run_id} is currently '{status}' "
            f"(attempt {attempt + 1}/{max_attempts}); waiting {poll_interval}s "
            f"for run to complete before rerunning..."
        )
        time.sleep(poll_interval)

    print(
        f"⚠️ Timed out waiting for GitHub Actions run {run_id} to complete.",
        file=sys.stderr,
    )
    return None


def retry_github_actions(repo, run_id, job_id=None, job_pattern=None, rebuild=False):
    check_cli("gh", "https://cli.github.com/")
    data = wait_for_github_run_completion(repo, run_id, job_id=job_id)
    jobs = data.get("jobs", []) if isinstance(data, dict) else []

    if rebuild:
        print(f"🚀 Re-running entire GitHub Actions run {run_id} ({repo})...")
        res = subprocess.run(["gh", "run", "rerun", str(run_id), "--repo", repo])
        return res.returncode

    if job_pattern:
        matched = []
        for j in jobs:
            name = j.get("name", "")
            jid = j.get("databaseId")
            conclusion = j.get("conclusion") or j.get("status") or ""
            if jid and (
                re.search(job_pattern, name, re.IGNORECASE)
                or job_pattern.lower() in name.lower()
            ):
                matched.append((str(jid), name, conclusion))

        if not matched:
            print(
                f"⚠️ No GitHub Actions jobs found matching '{job_pattern}' in run {run_id}.",
                file=sys.stderr,
            )
            return 1

        rc = 0
        for jid, name, conclusion in matched:
            print(
                f"🚀 Retrying GitHub Actions job '{name}' "
                f"(ID: {jid}, conclusion: {conclusion})..."
            )
            res = subprocess.run(["gh", "run", "rerun", "--job", jid, "--repo", repo])
            if res.returncode != 0:
                print(
                    f"⚠️ Single-job rerun failed for {jid}; falling back to "
                    f"'gh run rerun {run_id} --failed'..."
                )
                res = subprocess.run(
                    ["gh", "run", "rerun", str(run_id), "--failed", "--repo", repo]
                )
                return res.returncode
        return rc

    if job_id:
        active_jobs_by_id = {str(j.get("databaseId")): j for j in jobs}
        if data is not None and str(job_id) not in active_jobs_by_id:
            status = (data.get("status") or "").lower()
            conclusion = (data.get("conclusion") or "").lower()
            if status != "completed" or conclusion == "success":
                return 0

        target_job = active_jobs_by_id.get(str(job_id))
        if target_job and (target_job.get("conclusion") or "").lower() == "success":
            print(
                f"ℹ️ GitHub Actions job '{target_job.get('name')}' "
                f"(ID: {job_id}) already succeeded."
            )
            return 0

        print(f"🚀 Retrying GitHub Actions job {job_id} in run {run_id} ({repo})...")
        res = subprocess.run(
            ["gh", "run", "rerun", "--job", str(job_id), "--repo", repo]
        )
        if res.returncode == 0:
            return 0
        print(
            f"⚠️ Single-job rerun for {job_id} exited with {res.returncode}; "
            f"falling back to rerunning failed jobs in run {run_id}..."
        )

    if data is not None and (data.get("conclusion") or "").lower() == "success":
        print(f"ℹ️ GitHub Actions run {run_id} already succeeded.")
        return 0

    print(f"🚀 Retrying failed jobs in GitHub Actions run {run_id} ({repo})...")
    res = subprocess.run(
        ["gh", "run", "rerun", str(run_id), "--failed", "--repo", repo]
    )
    return res.returncode


def retry_github_job_by_id(job_id, repo=DEFAULT_GH_REPO):
    check_cli("gh", "https://cli.github.com/")
    cmd = ["gh", "api", f"repos/{repo}/actions/jobs/{job_id}"]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        out = res.stdout
        json_str = out[out.find("{") : out.rfind("}") + 1] if "{" in out else "{}"
        job_data = json.loads(json_str)
        run_id = job_data.get("run_id")
        if run_id:
            return retry_github_actions(repo, str(run_id), job_id=str(job_id))
    except Exception as e:
        print(
            f"⚠️ Could not resolve run_id for GitHub job {job_id} via API: {e}",
            file=sys.stderr,
        )
    print(f"🚀 Retrying GitHub Actions job ID: {job_id}...")
    res = subprocess.run(["gh", "run", "rerun", "--job", str(job_id), "--repo", repo])
    return res.returncode


def normalize_build_target(target):
    # Transforms https://buildkite.com/bazel/rules-python-python/builds/15707
    # into (org/pipeline, 15707)
    m = re.search(r"buildkite\.com/([^/]+/[^/]+)/builds/(\d+)", target)
    if m:
        return m.group(1), m.group(2)
    parts = target.split("/")
    if len(parts) == 3:
        return f"{parts[0]}/{parts[1]}", parts[2]
    elif len(parts) == 2:
        return parts[0], parts[1]
    return "bazel/rules-python-python", target


def retry_job_by_uuid(job_id):
    check_cli("bk", "https://github.com/buildkite/cli")
    print(f"🚀 Retrying individual Buildkite job UUID: {job_id}")
    return subprocess.run(["bk", "job", "retry", job_id])


def unblock_manual_jobs(jobs):
    unblocked = []
    for j in jobs:
        jstate = j.get("state", "")
        is_manual_block = j.get("type") == "manual" or j.get("unblockable") is True
        jid = j.get("id")
        if jid and jstate in ("blocked", "blocked_failed") and is_manual_block:
            jname = j.get("name") or j.get("label") or jid
            print(f"🔓 Unblocking manual approval job '{jname}' (ID: {jid})...")
            subprocess.run(["bk", "job", "unblock", jid, "--no-input"])
            unblocked.append(j)
    return unblocked


def retry_jobs_by_name(pipeline, build_number, job_pattern, exit_on_missing=True):
    check_cli("bk", "https://github.com/buildkite/cli")
    cmd = ["bk", "build", "view", str(build_number), "-p", pipeline, "--json"]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        jobs = data.get("jobs", [])
        matched = []
        for j in jobs:
            name = j.get("name", "") or j.get("label", "")
            state = j.get("state", "")
            jid = j.get("id")
            if jid and (
                re.search(job_pattern, name, re.IGNORECASE)
                or job_pattern.lower() in name.lower()
            ):
                matched.append((jid, name, state))

        if not matched:
            if exit_on_missing:
                print(
                    f"⚠️ No jobs found matching pattern '{job_pattern}' in build #{build_number}",
                    file=sys.stderr,
                )
                sys.exit(1)
            return False

        for jid, name, state in matched:
            print(f"🚀 Retrying job '{name}' (ID: {jid}, status: {state})...")
            subprocess.run(["bk", "job", "retry", jid])
        return True
    except Exception as e:
        print(f"❌ Error fetching build jobs: {e}", file=sys.stderr)
        if exit_on_missing:
            sys.exit(1)
        return False


def retry_buildkite_build(
    pipeline,
    build_number,
    job_name=None,
    unblock=False,
    rebuild=False,
    rebuild_if_no_failed_jobs=True,
):
    check_cli("bk", "https://github.com/buildkite/cli")
    if job_name:
        return retry_jobs_by_name(pipeline, build_number, job_name)
    elif unblock:
        cmd = [
            "bk",
            "build",
            "view",
            str(build_number),
            "-p",
            pipeline,
            "--json",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        unblocked = unblock_manual_jobs(data.get("jobs", []))
        if not unblocked:
            print(
                f"ℹ️ No blocked manual approval jobs found in build #{build_number}.",
                file=sys.stderr,
            )
        return True
    elif rebuild:
        print(f"🚀 Rebuilding entire build #{build_number} for pipeline: {pipeline}")
        res = subprocess.run(
            ["bk", "build", "rebuild", build_number, "-p", pipeline, "--yes"]
        )
        return res.returncode == 0
    else:
        cmd = [
            "bk",
            "build",
            "view",
            str(build_number),
            "-p",
            pipeline,
            "--json",
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            data = json.loads(res.stdout)
            jobs = data.get("jobs", [])
            unblocked_jobs = unblock_manual_jobs(jobs)
            failed_jobs = [
                j
                for j in jobs
                if j.get("state") in ("failed", "broken", "timed_out")
                and j.get("id")
                and not j.get("retried_in_job_uuid")
                and not j.get("retried_at")
            ]
            if failed_jobs:
                for j in failed_jobs:
                    jid = j["id"]
                    jname = j.get("name") or j.get("label") or jid
                    print(f"🚀 Retrying failed job '{jname}' (ID: {jid})...")
                    subprocess.run(["bk", "job", "retry", jid])
                return True
            elif unblocked_jobs:
                return True
            elif rebuild_if_no_failed_jobs:
                print(
                    f"🚀 Rebuilding entire build #{build_number} for pipeline: {pipeline}"
                )
                res = subprocess.run(
                    [
                        "bk",
                        "build",
                        "rebuild",
                        build_number,
                        "-p",
                        pipeline,
                        "--yes",
                    ]
                )
                return res.returncode == 0
            return False
        except Exception:
            if rebuild_if_no_failed_jobs:
                print(
                    f"🚀 Rebuilding entire build #{build_number} for pipeline: {pipeline}"
                )
                res = subprocess.run(
                    [
                        "bk",
                        "build",
                        "rebuild",
                        build_number,
                        "-p",
                        pipeline,
                        "--yes",
                    ]
                )
                return res.returncode == 0
            return False


def handle_pr_target(pr_number, job_name=None, unblock=False, rebuild=False):
    print(f"🔍 Inspecting PR #{pr_number} checks via gh...")
    checks = get_pr_checks(pr_number)

    bk_checks = []
    gh_checks = []
    for c in checks:
        link = c.get("link", "")
        if "buildkite.com" in link:
            bk_checks.append(c)
        elif parse_github_actions_url(link):
            gh_checks.append(c)

    if unblock:
        if not bk_checks:
            print(f"ℹ️ No Buildkite checks found for PR #{pr_number}.", file=sys.stderr)
            return 0
        for c in bk_checks:
            pipeline, build_number = normalize_build_target(c["link"].split("#")[0])
            retry_buildkite_build(pipeline, build_number, unblock=True)
        return 0

    if job_name:
        matched_any = False
        matched_gh_runs = {}
        for c in gh_checks:
            cname = c.get("name", "")
            parsed = parse_github_actions_url(c.get("link", ""))
            if parsed and (
                re.search(job_name, cname, re.IGNORECASE)
                or job_name.lower() in cname.lower()
            ):
                repo, run_id, job_id = parsed
                matched_gh_runs.setdefault((repo, run_id), []).append(job_id)

        for (repo, run_id), job_ids in matched_gh_runs.items():
            matched_any = True
            if len(job_ids) == 1 and job_ids[0]:
                retry_github_actions(repo, run_id, job_id=job_ids[0])
            else:
                retry_github_actions(repo, run_id, job_pattern=job_name)

        for c in bk_checks:
            pipeline, build_number = normalize_build_target(c["link"].split("#")[0])
            if retry_jobs_by_name(
                pipeline, build_number, job_name, exit_on_missing=False
            ):
                matched_any = True

        if not matched_any:
            print(
                f"⚠️ No GitHub Actions or Buildkite jobs found matching "
                f"'{job_name}' for PR #{pr_number}.",
                file=sys.stderr,
            )
            return 1
        return 0

    # Retry failed GitHub Actions checks (or rebuild all failed runs if --rebuild)
    failed_gh_runs = {}
    for c in gh_checks:
        state = (c.get("state") or "").upper()
        bucket = (c.get("bucket") or "").lower()
        is_failed = (
            state in ("FAILURE", "FAIL", "CANCELLED", "TIMED_OUT", "STARTUP_FAILURE")
            or bucket == "fail"
        )
        if is_failed or rebuild:
            parsed = parse_github_actions_url(c.get("link", ""))
            if parsed:
                repo, run_id, job_id = parsed
                if is_failed:
                    failed_gh_runs.setdefault((repo, run_id), []).append(job_id)

    gh_retried = False
    for (repo, run_id), job_ids in failed_gh_runs.items():
        gh_retried = True
        if rebuild:
            retry_github_actions(repo, run_id, rebuild=True)
        elif len(job_ids) == 1 and job_ids[0]:
            retry_github_actions(repo, run_id, job_id=job_ids[0])
        else:
            retry_github_actions(repo, run_id)

    # Check Buildkite builds
    for c in bk_checks:
        pipeline, build_number = normalize_build_target(c["link"].split("#")[0])
        state = (c.get("state") or "").upper()
        bucket = (c.get("bucket") or "").lower()
        bk_failed = (
            state in ("FAILURE", "FAIL", "CANCELLED", "TIMED_OUT") or bucket == "fail"
        )
        retry_buildkite_build(
            pipeline,
            build_number,
            rebuild=rebuild,
            rebuild_if_no_failed_jobs=(bk_failed and not gh_retried),
        )

    if not bk_checks and not gh_retried:
        print(
            f"ℹ️ No failing GitHub Actions or Buildkite checks found for PR #{pr_number}."
        )
    return 0


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Retry failed Buildkite or GitHub Actions jobs individually, "
            "unblock Buildkite approval steps, or rebuild entire builds."
        )
    )
    parser.add_argument(
        "args",
        nargs="*",
        help=(
            "Target build (PR#, Buildkite URL, GitHub Actions run/job URL, "
            "or org/pipeline/build)"
        ),
    )
    parser.add_argument(
        "--jobs",
        "--job-name",
        dest="job_name",
        help="Specific job name or regex pattern to retry individually",
    )
    parser.add_argument(
        "--job-id",
        dest="job_id",
        help=(
            "Specific Buildkite job UUID or GitHub Actions job ID to retry individually"
        ),
    )
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="Rebuild the entire build afresh",
    )
    parser.add_argument(
        "--unblock",
        action="store_true",
        help=(
            "Unblock manual approval steps (e.g. .bazelci/presubmit.yml "
            "changes) via 'bk job unblock'"
        ),
    )
    args = parser.parse_args()

    if args.job_id:
        gh_parsed = parse_github_actions_url(args.job_id)
        if gh_parsed:
            repo, run_id, job_id = gh_parsed
            sys.exit(
                retry_github_actions(
                    repo,
                    run_id,
                    job_id=job_id,
                    job_pattern=args.job_name,
                    rebuild=args.rebuild,
                )
            )
        if args.job_id.isdigit():
            sys.exit(retry_github_job_by_id(args.job_id))
        res = retry_job_by_uuid(args.job_id)
        sys.exit(res.returncode)

    if len(args.args) == 3:
        target = f"{args.args[0]}/{args.args[1]}/{args.args[2]}"
    elif len(args.args) == 1:
        target = args.args[0]
    else:
        print(
            "❌ Error: Invalid arguments. Provide a single target "
            "(PR#, Buildkite URL, GitHub Actions URL, or org/pipeline/build).",
            file=sys.stderr,
        )
        sys.exit(1)

    gh_parsed = parse_github_actions_url(target)
    if gh_parsed:
        repo, run_id, job_id = gh_parsed
        sys.exit(
            retry_github_actions(
                repo,
                run_id,
                job_id=job_id,
                job_pattern=args.job_name,
                rebuild=args.rebuild,
            )
        )

    if target.isdigit() and len(target) < 10:
        sys.exit(
            handle_pr_target(
                target,
                job_name=args.job_name,
                unblock=args.unblock,
                rebuild=args.rebuild,
            )
        )

    pipeline, build_number = normalize_build_target(target)
    ok = retry_buildkite_build(
        pipeline,
        build_number,
        job_name=args.job_name,
        unblock=args.unblock,
        rebuild=args.rebuild,
        rebuild_if_no_failed_jobs=True,
    )
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
