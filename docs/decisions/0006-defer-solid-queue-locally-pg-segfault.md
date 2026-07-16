# 6. Defer Solid Queue in development, use :async instead

## Status
Accepted (temporary — revisit before deploy)

## Context
Tried wiring Solid Queue as the real ActiveJob adapter in development too
(matching production), so `bin/jobs` would run the same backend the app
uses when deployed. Along the way, fixed a real bug: the `queue` database
connection wasn't inheriting `DATABASE_URL` (Rails only auto-applies it to
a connection named `primary`), so it silently fell back to the Postgres
default port and was creating its tables on an unrelated native Postgres
install on this machine instead of our actual dev database. Fixed by
setting `url:` explicitly for both connections in `config/database.yml`
(kept — this was a real, worth-fixing bug regardless of the below).

Once the routing was fixed and the `solid_queue_*` tables existed in the
right place, `bin/jobs` still crashed: a segfault inside the native `pg`
gem (`pg-1.6.3-arm64-darwin`), specifically in `connect_start`, when
Solid Queue's supervisor opens multiple concurrent database connections
(dispatcher + worker threads each connect independently).

## Decision
Reverted `config.active_job.queue_adapter` in development back to the
Rails default (`:async` — in-process thread pool, no separate worker or
database tables needed). Production's config (`solid_queue`, in
`config/environments/production.rb`) is untouched and unaffected.

## Why
- `:async` is a legitimate standard choice for local development, not a
  hack — CLAUDE.md's actual requirement was avoiding Redis/Sidekiq, not
  mandating a literal running `bin/jobs` process during every dev session.
- Everything built so far (tests via the `:test` adapter, manual
  verification via `perform_now`) works correctly under this reversion —
  nothing regressed.
- A native-extension segfault under concurrent connections is a
  substantial debugging effort (likely means rebuilding `pg` from source
  against a specific libpq, or a `gem pristine` cycle) that doesn't block
  any current feature work.

## Tradeoffs accepted
- Local dev doesn't currently exercise the real Solid Queue code path
  (retry behavior, concurrency limits, recurring tasks) — only `:async`'s
  simpler in-process behavior.
- **Must revisit before Phase 6 (deploy)** — production genuinely needs
  Solid Queue to run via `bin/jobs` (or equivalent), so this segfault has
  to be resolved (or root-caused as something that won't occur on the
  actual deploy target) before shipping.
