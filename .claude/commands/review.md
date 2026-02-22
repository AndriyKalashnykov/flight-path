Review all uncommitted changes in the working tree:

1. Run `git status` to see modified, added, and deleted files
2. Run `git diff` to see unstaged changes and `git diff --cached` to see staged changes
3. For each changed file, analyze the diff and check for:
   - **Bugs**: Logic errors, nil pointer risks, off-by-one errors, race conditions
   - **Security**: Injection vulnerabilities, hardcoded secrets, unsafe input handling
   - **Style**: Violations of project conventions from CLAUDE.md (naming, error handling, formatting)
   - **Tests**: Whether new/changed code has adequate test coverage
   - **Swagger**: Whether endpoint changes need Swagger annotation updates
4. Provide a summary table of findings by file with severity (info/warning/error)
5. Suggest specific fixes for any issues found

If there are no uncommitted changes, say so and suggest running `git log -5 --oneline` to review recent commits instead.
