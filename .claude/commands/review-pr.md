---
allowed-tools: Bash(gh pr view*), Bash(gh pr diff*), Bash(gh api*), Bash(git log*), Bash(git diff*)
---

Review PR #$ARGUMENTS for quality, security, and correctness.

## Steps

1. Run `gh pr view $ARGUMENTS` to get PR title, description, base branch, and status
2. Run `gh pr diff $ARGUMENTS` to get the full diff
3. For each changed file, analyze the diff and check for:
   - **Bugs**: Logic errors, nil pointer risks, off-by-one errors, race conditions
   - **Security**: Injection vulnerabilities, hardcoded secrets, unsafe input handling (OWASP Top 10)
   - **Style**: Violations of project conventions from CLAUDE.md (naming, error handling, formatting)
   - **Tests**: Whether new/changed code has adequate test coverage
   - **Swagger**: Whether endpoint changes need Swagger annotation updates
   - **Error handling**: Errors returned up the stack, logged at handler level
   - **Input validation**: Validated before processing, 400 for bad input
4. Read any files that need full context to understand the changes
5. Provide a summary table of findings by file with severity (CRITICAL / HIGH / MEDIUM / LOW / INFO)
6. For CRITICAL and HIGH issues, suggest specific fixes with code snippets
7. Give an overall verdict: APPROVE, REQUEST_CHANGES, or COMMENT
