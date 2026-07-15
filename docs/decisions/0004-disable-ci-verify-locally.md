# 4. Disable CI, verify locally before merging

## Status
Accepted

## Context
Branch protection on `main` required 5 GitHub Actions checks (rubocop,
brakeman, bundler-audit, importmap audit, tests, system tests) to pass
before a PR could merge. Each PR was waiting several minutes for a
GitHub-hosted runner to redo checks that had already been run locally
moments earlier, with no second reviewer benefiting from the CI run — this
is a solo project.

## Decision
Disabled the CI workflow (`gh workflow disable "CI"`) and removed
`required_status_checks` from branch protection. `main` still requires a
PR (no direct pushes) — that part of the workflow stays, for a clean
one-commit-per-PR history. The requirement to run `bundle exec rubocop`
and `bin/rails test` before merging moved from "CI enforces it" to
"documented in CONTRIBUTING.md, self-enforced."

## Why
- No second contributor exists to benefit from an automated second check
  — the value CI normally adds (catching what the author's local run
  might have skipped) doesn't apply when the author already ran the exact
  same commands locally right before pushing.
- The multi-minute wait per PR was pure latency during active
  development, without a corresponding safety benefit at this project's
  current stage.

## Tradeoffs accepted
- No automated re-verification if local checks are accidentally skipped —
  trust shifts entirely to discipline (`CONTRIBUTING.md`'s workflow step
  3), not tooling.
- No security scanning (brakeman/bundler-audit) or dependency-drift
  catching between local runs — acceptable pre-launch, not once this
  handles real user data or gets deployed.
- **Re-enable before it matters**: a second contributor joining, or
  approaching the Phase 6 deploy — re-run `gh workflow enable "CI"` and
  restore `required_status_checks` in branch protection at that point.
