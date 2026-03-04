---
allowed-tools: Bash(gh pr list*), Bash(gh pr view*)
---

List open PRs for this repository.

## Steps

1. Run `gh pr list --state open` to show all open PRs with number, title, branch, and author
2. Summarize the results in a table with columns: PR #, Title, Branch, Author, Updated
3. If no open PRs exist, say so
