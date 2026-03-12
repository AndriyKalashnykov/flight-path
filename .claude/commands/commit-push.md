---
allowed-tools: Bash(git *), Bash(gh *), Bash(make *), Read, Glob, Grep, Edit, Write
description: "Commit all changes, push to remote, and optionally monitor CI workflow to completion. Usage: /commit-push [wait|nowait] [timeout_minutes]"
---

Commit all changes, push to remote, and monitor the CI workflow.

**Arguments** (passed via $ARGUMENTS):
- First arg: `wait` (default) or `nowait` — whether to monitor the CI workflow after pushing
- Second arg: timeout in minutes (default: `10`) — how long to wait for CI completion (only used with `wait`)

Parse arguments from: $ARGUMENTS

## Phase 1: Commit & Push

1. Run these in parallel to understand current state:
   - `git status` (never use `-uall` flag)
   - `git diff` and `git diff --cached` to see all changes
   - `git log -5 --oneline` to follow commit message style conventions

2. If there are no changes (no untracked, no modified, no staged), stop and inform the user.

3. Analyze all changes and draft a commit message:
   - Use conventional commits format: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `perf:`, `ci:`
   - Focus on the "why" not the "what"
   - Keep the first line concise (under 72 characters)
   - Do NOT commit files that likely contain secrets (`.env`, credentials, tokens, etc.) — warn the user if found

4. Stage relevant files by name (prefer specific files over `git add -A`).

5. Create the commit. Always use a HEREDOC for the commit message:
   ```
   git commit -m "$(cat <<'EOF'
   <type>: <description>
   EOF
   )"
   ```

6. Push to remote:
   - If the current branch has no upstream, use `git push -u origin <branch>`
   - Otherwise use `git push`

7. Run `git status` after push to verify success.

## Phase 2: CI Monitoring (skip if `nowait`)

If the first argument is `nowait`, stop here and inform the user the push succeeded.

Otherwise, continue with CI monitoring:

1. Wait a few seconds, then find the triggered workflow run:
   ```
   gh run list --branch <current-branch> --limit 1 --json databaseId,status,conclusion,headSha
   ```
   Verify the `headSha` matches the commit just pushed. If not, wait and retry.

2. Monitor the workflow using `gh run watch <run-id> --exit-status` with a timeout of the specified minutes (default 10, converted to milliseconds for the timeout parameter, max 600000ms).

3. **If CI passes**: Report success with job summary.

4. **If CI fails**: Automatically diagnose and fix:
   a. Fetch failed job logs: `gh run view <run-id> --log-failed`
   b. Analyze the failure — identify which job and step failed
   c. Read the relevant source files
   d. Fix the issue (formatting, lint, test, build errors)
   e. Verify the fix locally if possible (e.g., `make fmtcheck`, `make test`, `make build`)
   f. Go back to Phase 1 — commit the fix, push, and re-monitor
   g. If the fix loop exceeds 3 attempts, stop and ask the user for help

## Important Rules

- Never amend existing commits — always create new commits
- Never use `--no-verify` or skip hooks
- Never force push
- Never commit secrets or sensitive files
- If the user denies a tool call, adjust approach — don't retry the same call
