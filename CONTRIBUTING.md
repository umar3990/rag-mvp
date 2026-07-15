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

## Secrets & credentials

This project touches three external secrets: an LLM API key, Gmail OAuth
credentials, and an n8n webhook auth token. Two different places to put
them, depending on scope:

- **`.env`** (gitignored, never committed) — local development
  convenience. Loaded automatically via `dotenv-rails`. Copy
  `.env.example` to `.env` and fill in real values. This is where your
  personal dev API keys live.
- **Rails encrypted credentials** (`config/credentials.yml.enc`, edited via
  `bin/rails credentials:edit`) — anything that needs to exist in
  *production*. The encryption key (`config/master.key`) is itself
  gitignored and never committed; it's what Kamal reads at deploy time
  (see `.kamal/secrets`).

Rule of thumb: if it's a value you personally use to develop locally, it's
`.env`. If it's a value the deployed app needs at runtime, it's Rails
credentials. Never put a real secret directly in `docker-compose.yml`,
`config/database.yml`, or any file that isn't gitignored — check
`git status` after adding a new secret to make sure it landed somewhere
ignored, not staged.

Tests must never hit real external APIs (embeddings, Gmail) — see
`test/test_helper.rb`'s VCR setup, which records a real response once into
a cassette (`test/vcr_cassettes/`, committed, secrets auto-filtered out)
and replays it on every subsequent run.

## Docs to keep in sync

- `CLAUDE.md` progress tracker — check off a day when its milestone lands.
- `notes.md` — a checkpoint log for resuming cold, not documentation.
  Append a *short* entry per session: what shipped (with PR numbers, not
  re-explained detail), what's pending, and only decisions not already
  captured in a commit message or ADR. A few bullets, not a narrative.
  Once it grows past ~5 entries, move older ones into
  `docs/notes-archive/YYYY-MM.md` (newest-first, same format) — it gets
  read into context regularly, so keeping it small keeps that cheap.
- `docs/decisions/` — add a new numbered ADR for any non-obvious technical
  choice (why Postgres over X, why this chunking strategy, etc.).
