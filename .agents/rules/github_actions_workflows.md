---
name: github-actions-workflows
trigger: glob
globs: ".github/workflows/**,.github/actions/**"
---

# GitHub Actions Workflows Rule

* Use the latest version of referenced actions in `.github/workflows/`.
* **Use Local Composite Actions (`./.github/actions/setup-bazel`)**: Always use
  local composite action wrappers (such as
  `uses: ./.github/actions/setup-bazel`) instead of invoking upstream actions
  like `bazel-contrib/setup-bazel` directly in `.github/workflows/`. Update
  `.github/actions/setup-bazel/action.yaml` if project defaults or inputs need
  adjustment.
* Preserve `suppress-no-jobs-ran-error` fallback jobs in conditional workflows.
* Pass inputs (e.g. `${{ inputs.issue }}`) directly to commands without
  redundant shell stripping.
* Print console messages using GitHub workflow commands (e.g., `::error::`,
  `::warning::`, `::notice::`, `::group::`).
* **Event Payload Resolution**: For steps that are a single Python script,
  loading event details directly from `$GITHUB_EVENT_PATH` is required (strong
  suggestion otherwise) rather than passing fields via env vars or CLI flags.
* **Preserve `export-subst` in `git archive`**: Always pass a commit or tag ref
  (never a raw `git write-tree` SHA) to `git archive` so `.gitattributes`
  `export-subst` placeholders (such as `$Format:...$` in `python/features.bzl`)
  expand. Use `--add-file` to include generated files.
* **Ref Handling (Tags vs. Commits)**: When a workflow or script processes a
  release tag or a commit (e.g. in presubmit), use that exact tag or commit SHA
  value throughout. Never invent dummy version strings (e.g. `0.0.0-dev`) or
  create synthetic git tags to work around downstream logic.
* **No `--stamp` or `--embed_label` on Pull Requests**: Only pass `--stamp` and
  `--embed_label` on release builds, never on `pull_request` builds, to avoid
  busting remote/RBE caching.
* **Direct `bazel-bin/` Tool Execution**: When a workflow step runs a Bazel
  binary directly from `bazel-bin/<pkg>/<target>` instead of `bazel run`,
  explicitly include `//<pkg>:<target>` in `bazel build` so its `.runfiles` tree
  is materialized.

## Workflow Scripts & Testing
* **Separate Script Files (No Inline Scripts)**: Factor non-trivial scripts
  (such as multi-line shell or Python logic) into standalone files (e.g. `.sh`
  or `.py` files) instead of inlining them in workflow YAML steps (`run: |`),
  shell scripts, or command invocations via heredocs (`<< 'EOF'`) or `-c` flags
  (`bash -c`, `python3 -c`).
* **Executable Permissions**: Workflow step scripts must have `chmod +x` (mode
  `100755`) and a shebang (e.g. `#!/usr/bin/env python3`).
* **Test Location**: Place workflow tests under `tests/workflows/`.
* **Imports over `sys.path`**: Never alter `sys.path`. Define a `py_library`
  with `imports = ["../../.github/workflows"]` in `tests/workflows/BUILD.bazel`.
* **Functional Design & Fixtures**: Keep scripts functional with one public
  entry point (e.g. `process_comment()`) and private helpers (`_` prefix). Write
  outputs directly when matching actions. Test end-to-end via autouse fixtures
  for GHA env files and API mocks.
* **Git Portability in Workflow Tests**: CI runs on older Linux distributions
  with Git `< 2.35` (e.g. Debian 11, Ubuntu 22.04), where
  `%(describe:tags=true)` is unsupported. Guard assertions on Git $\ge$ 2.35
  format options with a host Git capability check.
