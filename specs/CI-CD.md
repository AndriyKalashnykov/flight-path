# CI/CD Specification

Every CI job and the full release pipeline live in a single workflow file (`.github/workflows/ci.yml`), with tag-gated sibling jobs for the release phase. Supporting workflows (`claude.yml`, `claude-ci-fix.yml`, `cleanup-runs.yml`) are separate.

## `ci.yml`

### Triggers

- Push to `main`
- Push of tags matching `v*`
- Pull requests targeting `main`

`paths-ignore` excludes documentation, images, benchmarks, `.claude/**`, and other non-critical files; `CLAUDE.md` is re-included via `!CLAUDE.md`. Tags are unaffected by `paths-ignore`.

### Permissions

Default `contents: read`. Elevated permissions are scoped per job that needs them — e.g. the `docker` job sets `packages: write` + `id-token: write` on the steps that push and sign.

### Jobs

| Job | Triggers | Depends on | Timeout | Steps |
|---|---|---|---|---|
| **static-check** | all | — | 15 min | `mise install`, `make static-check` (lint-ci + lint + sec + vulncheck + secrets + trivy-fs + mermaid-lint + release-check) |
| **build** | all | static-check | 10 min | `go build`, upload `server-binary` artifact |
| **test** | all | static-check | 15 min | `make coverage-check` (80% floor), upload coverage artifact |
| **integration-test** | all | static-check | 10 min | `make integration-test` — full HTTP stack via `httptest` and `//go:build integration` |
| **e2e** | all | build, test | 15 min | Download binary (fallback: rebuild when artifact download fails), start server, run Newman collection. Runs identically under `act` via `make ci-run`. |
| **dast** | all except under `act` (`vars.ACT == 'true'` skips) | build, test | 15 min | Download binary, start server, run OWASP ZAP API scan against `swagger.json`. Skipped in `act` because ZAP needs Docker-in-Docker. |
| **docker** | all | static-check, build, test | 30 min | Gate 1–3 every push (build, Trivy image scan, smoke test). Gate 4 multi-arch build every push; push only when `startsWith(github.ref, 'refs/tags/')`. Gate 5 cosign signing tag-only. |
| **goreleaser** | tag push only | all above | 30 min | GoReleaser builds binaries, archives, checksums, changelog; creates the GitHub Release |
| **ci-pass** | always | every upstream job | — | Aggregator with `if: always()`; fails only when `contains(needs.*.result, 'failure')`. Single required check for branch protection. On non-tag pushes, `goreleaser` is `skipped` (not `failure`) and the aggregator still passes. |

### Required secrets

| Secret | Used by | How to obtain |
|---|---|---|
| `GITHUB_TOKEN` | all jobs that touch Actions artifacts, GHCR, releases | Auto-injected by GitHub Actions |
| `CLAUDE_CONFIG_TOKEN` | `claude.yml`, `claude-ci-fix.yml` | PAT with `contents: read` on `AndriyKalashnykov/claude-config` so those workflows can check out shared config |
| `ANTHROPIC_API_KEY` | `claude.yml`, `claude-ci-fix.yml` | [console.anthropic.com](https://console.anthropic.com/) API key |

### Repository variables

| Variable | Purpose |
|---|---|
| `ACT` | Set to `"true"` locally via `make ci-run --var ACT=true` to skip the `dast` job. Not set on GitHub-hosted runners. |

## Release process (`make release`)

1. `make ci` — run the full local pipeline
2. Prompt for new tag, write to `pkg/api/version.txt`
3. `git commit -a -s -m "Cut <tag> release"`
4. `git tag <tag> && git push origin <tag> && git push`
5. GitHub Actions runs `ci.yml` on the tag — static-check, build, test, integration-test, e2e, dast, docker (including GHCR push + cosign sign), goreleaser — then `ci-pass` aggregates

There is no separate `release.yml`. Tag-only behavior is implemented via `if: startsWith(github.ref, 'refs/tags/')` on the relevant steps inside `ci.yml`.

## `claude.yml`

Interactive Claude workflow — responds to `@claude` mentions in issues/PRs and performs automated PR reviews on every non-draft PR. Restricted to `author_association` in `{OWNER, MEMBER, COLLABORATOR}`. Uses `CLAUDE_CONFIG_TOKEN` + `ANTHROPIC_API_KEY`.

## `claude-ci-fix.yml`

Auto-triggers on CI failures via `workflow_run` for same-repo PR branches. Attempts to produce a fix commit. Dual anti-recursion guard:

1. Bot-author check — skip if the failing run was authored by the bot itself
2. `claude-fix-attempted` label — skip if already attempted on this PR

Caps total CI-log input at 12K characters to prevent prompt-injection context stuffing.

## `cleanup-runs.yml`

Scheduled weekly (Sundays 00:00 UTC). Deletes workflow runs older than 7 days, keeps a minimum of 5, and prunes caches on merged or deleted branches.

## Dependency automation

Renovate (`renovate.json`) raises PRs for all tracked dependencies with platform automerge enabled for low-risk updates (minor/patch, pin updates, Docker digest refresh).
