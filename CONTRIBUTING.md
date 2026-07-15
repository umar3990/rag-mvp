# Contributing

Solo learning project, but run like a small team's repo: `main` is always
deployable, all changes land via pull request, no direct pushes to `main`.

## Branch naming

`<type>/<short-description>`, e.g. `feat/document-upload`,
`fix/chunk-boundary-off-by-one`, `chore/add-rubocop`.

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`.

## Commits

Conventional-commit style subject line: `type: short imperative summary`,
e.g. `feat: add pdf text extraction job`. Body explains *why* when it's not
obvious from the diff — mirrors the "why" emphasis in `CLAUDE.md`.

## Workflow

1. Branch off `main`.
2. Commit as you go.
3. Open a PR using the template — fill in What / Why / How to test.
4. CI (rubocop + tests) must pass.
5. Merge via GitHub (squash merge keeps `main` history one-commit-per-PR).
6. Delete the branch after merge.

## Code style

Rubocop config is `rubocop-rails-omakase` (Rails 8's default) — run
`bundle exec rubocop -A` to auto-fix before opening a PR.

## Docs to keep in sync

- `CLAUDE.md` progress tracker — check off a day when its milestone lands.
- `notes.md` — append an entry per session: what got built, why, tradeoffs.
- `docs/decisions/` — add a new numbered ADR for any non-obvious technical
  choice (why Postgres over X, why this chunking strategy, etc.).
