---
name: buildkite-retry-job
description: Retry failed Buildkite jobs, unblock manual approval steps, or
  rebuild full builds
---

Use `scripts/retry_buildkite_jobs.py` to retry individual jobs, unblock manual
approval steps (such as `.bazelci/presubmit.yml` changes), or rebuild full
Buildkite builds.

### Retrying & Unblocking Modes

1. **Default Retry & Unblock**:
   Unblocks any blocked manual approval steps (`bk job unblock <job_id>
   --no-input`) and retries specific failing jobs (`bk job retry <job_id>`):
   ```bash
   ./.agents/skills/buildkite-retry-job/scripts/retry_buildkite_jobs.py \
     <pr_number_or_url>
   ```

2. **Unblock Manual Approval Steps (e.g. `.bazelci/presubmit.yml` changes)**:
   Approves and unblocks blocked manual approval steps without retrying or
   rebuilding other jobs:
   ```bash
   ./.agents/skills/buildkite-retry-job/scripts/retry_buildkite_jobs.py \
     <pr_number_or_url> --unblock
   ```

3. **Retry Specific Jobs by Name or ID**:
   ```bash
   ./.agents/skills/buildkite-retry-job/scripts/retry_buildkite_jobs.py \
     <pr_number> --jobs "compile_pip_requirements"
   ./.agents/skills/buildkite-retry-job/scripts/retry_buildkite_jobs.py \
     --job-id <job_uuid>
   ```

4. **Rebuild Full Build**:
   Re-runs the entire pipeline build from scratch via `bk build rebuild`:
   ```bash
   ./.agents/skills/buildkite-retry-job/scripts/retry_buildkite_jobs.py \
     <pr_number> --rebuild
   ```
