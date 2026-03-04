Guide me through creating a new release for this project:

1. Show the current version from `pkg/api/version.txt` and the latest git tag
2. Ask what the new version should be (suggest next patch, minor, and major versions)
3. Run the full pre-commit checklist:
   - `make lint`
   - `make sec`
   - `make vulncheck`
   - `make secrets`
   - `make lint-ci`
   - `make test`
   - `make api-docs`
   - `make build`
4. If all checks pass, confirm the new version with me before proceeding
5. Update `pkg/api/version.txt` with the new version
6. Run `make api-docs` to regenerate docs with the new version
7. Show the exact git commands that will be run (commit, tag, push) and ask for final confirmation
8. Only after my explicit approval, execute the release commands

Do NOT push or tag without my explicit confirmation at each step.
