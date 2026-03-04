---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add *), Bash(git commit *), Bash(git push*), Bash(git branch*), Bash(git checkout*), Bash(gh pr create*)
---

Commit all changes, push to remote, and create a PR for review.

## Steps

1. Run `git status` to see all changes (staged, unstaged, untracked)
2. Run `git diff` and `git diff --cached` to review what will be committed
3. Run `git log -5 --oneline` to check recent commit message style
4. If there are no changes, stop and inform the user
5. If on `main` branch, create a new feature branch from the changes:
   - Analyze the changes to generate a descriptive branch name (e.g., `feat/add-validation`, `fix/null-pointer`)
   - Run `git checkout -b <branch-name>`
6. Stage all relevant changes (exclude `.env`, credentials, or generated files in `docs/`)
7. Draft a commit message following conventional commits format (`feat:`, `fix:`, `refactor:`, etc.)
8. Show the user the staged files and proposed commit message, then ask for confirmation
9. Commit the changes
10. Push the branch to remote with `git push -u origin <branch-name>`
11. Create a PR using `gh pr create` with:
    - A concise title (under 70 characters)
    - Body with `## Summary` (bullet points of changes) and `## Test plan` (checklist)
    - Base branch: `main`
12. Return the PR URL to the user
