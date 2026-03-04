---
allowed-tools: Bash(gh pr view*), Bash(gh pr diff*), Bash(gh pr review*), Bash(gh pr merge*), Bash(git pull*), Bash(git log*), Bash(git checkout*)
---

Approve and merge a PR. Usage: `/accept-pr <me|claude> <pr-number>`

Parse `$ARGUMENTS` to extract the signer and PR number. The first word is the signer (`me` or `claude`), the second is the PR number.

## Steps

1. Parse `$ARGUMENTS` — expect two values: `<signer>` and `<pr-number>`
   - If missing or invalid, show usage and stop
   - Valid signers: `me` (user's git identity) or `claude` (Claude as author)
2. Run `gh pr view <pr-number> --json title,state,body,baseRefName,headRefName,commits,files` to verify the PR exists and is open
3. Run `gh pr diff <pr-number>` to review the changes
4. Provide a brief summary of what the PR does
5. Ask the user to confirm the merge
6. Try to approve the PR: `gh pr review <pr-number> --approve --body "LGTM"`
   - If self-approve fails (own PR), skip approval and proceed to merge
7. Merge the PR based on signer:
   - **me**: `gh pr merge <pr-number> --squash --delete-branch`
   - **claude**: `gh pr merge <pr-number> --squash --delete-branch --author-email "noreply@anthropic.com"`
8. Run `git checkout main && git pull` to sync local main
9. Show the merge result
