---
name: review-code
description: High-level code review audit of local changes when preparing to
  send a PR for review
trigger: model_decision
---

When preparing to send a Pull Request for review, invoke **separate, concurrent
sub-agents** (`invoke_subagent`), where each sub-agent focuses exclusively on
its assigned checklist category.

**CRITICAL**: Do NOT use a single sub-agent to validate multiple or all
dimensions at once. Each sub-agent must be launched with its own distinct prompt
file from `.agents/skills/review-code/`:

### Audit Checklist & Sub-Agent Prompts

1. **Starlark / Bazel Sub-Agent** (`Role: "Starlark Code Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-starlark-prompt.md`
   - Focus: Audits Starlark / Bazel changes (`*.bzl`, `BUILD`, `*.bazel` files)
     in `git diff` against `.agents/rules/bzl.md` and Starlark rules in
     `AGENTS.md`.

2. **Python Code Sub-Agent** (`Role: "Python Code Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-python-prompt.md`
   - Focus: Audits Python source, test, and inline script changes in `git diff`
     against `.agents/rules/python.md` and Python and pytest conventions in
     `AGENTS.md`.

3. **Documentation Sub-Agent** (`Role: "Documentation Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-docs-prompt.md`
   - Focus: Audits documentation (`.md`) changes and docs build targets against
     `.agents/rules/docs.md` and `AGENTS.md`.

4. **Contribution Guidelines Sub-Agent** (`Role: "Contributing Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-contributing-prompt.md`
   - Focus: Audits changes, requirements updates, and version directives against
     `CONTRIBUTING.md`.

5. **Project Conventions Sub-Agent** (`Role: "Project Conventions Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-agents-prompt.md`
   - Focus: Audits overall workspace compliance against `AGENTS.md`.

6. **Pull Request Standards Sub-Agent** (`Role: "PR Standards Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-pr-standards-prompt.md`
   - Focus: Audits PR titles and descriptions against Conventional Commits
     formatting, PR update rules in `CONTRIBUTING.md`, and open questions or
     "TODO / Things we could do" items in the PR description (ensuring the
     `"do not merge"` label is applied when open questions exist).

7. **GitHub Workflows Sub-Agent** (`Role: "GitHub Workflows Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-workflows-prompt.md`
   - Focus: Audits workflow files (`.github/**`) and workflow tests against
     `.agents/rules/github_actions_workflows.md` (e.g. `chmod +x` executable
     permissions, shebangs, action versions, `./.github/actions/setup-bazel`
     wrapper usage, fallback jobs).

8. **`rules_python` Usage Sub-Agent** (`Role: "rules_python Usage Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-rules-python-prompt.md`
   - Focus: Audits changes against `.agents/rules/rules_python.md` (e.g.,
     `pip.dep()` declarations in `MODULE.bazel` and `MINIMUM_BAZEL_VERSION`
     bounds).

9. **News Entry Sub-Agent** (`Role: "News Entry Auditor"`):
   - Prompt file:
     `.agents/skills/review-code/review-news-prompt.md`
   - Focus: Audits `news/<id>.<category>.md` files for presence, naming (no
     generic `0000` placeholders), brevity and skimmability, and formatting
     against `.agents/rules/news.md` and
     `.agents/skills/create-news/SKILL.md`.

### Action Instructions
- Immediately create a user-facing review artifact named
  `code-review-results.md` in the conversation artifact directory so progress
  is visible right away.
- Have sub-agents run `git diff $(git merge-base HEAD upstream/main)` to audit
  committed and uncommitted branch changes without newer `upstream/main`
  commits.
- Launch all sub-agents concurrently using `invoke_subagent`.
- Update `code-review-results.md` as sub-agent responses come in.
- The artifact must include:
  - Overall summary and verdict across audit categories.
  - Detailed analysis and findings from each sub-agent.
  - Actionable findings and fix suggestions with specific code snippets, diffs,
    and clickable file links for any violations found.
- Once all sub-agents finish, finalize `code-review-results.md` and provide a
  concise summary with the overall verdict and a clickable markdown link to
  `code-review-results.md` in the response.
- If a PR is being reviewed, ask the user if they want to post comments to the
  PR.
- When posting comments to the PR, add a note in italics at the end of each
  comment identifying it as an agent-generated comment and referring to yourself
  using a magnanimous title.
