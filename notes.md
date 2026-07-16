# Notes — AI Business Automation Platform

Checkpoint log for resuming cold — not documentation, not duplicated from
commit messages/PRs. One short entry per session: what shipped, what's
pending, and only decisions not already captured elsewhere (ADRs, commit
messages). Newest on top. Archive older entries to
`docs/notes-archive/YYYY-MM.md` once this passes ~5 entries.

---

## 2026-07-16 (cont. 3) — Retry mechanism, live status via Turbo Streams

- Shipped: `retry_on`/`discard_on` on `DocumentProcessingJob` (transient
  errors retry with backoff; permanent ones like unsupported file type
  fail immediately). Manual "Retry" button (index + show) for
  permanently-failed documents. `broadcasts_to`/`broadcasts_refreshes` so
  index/show pages update live over Turbo Streams instead of needing a
  manual reload.
- Fixed two real bugs found while verifying against the user's actual
  uploads (not just the test suite):
  1. `retry_on`/`discard_on` handlers are searched bottom-to-top (most
     recently declared wins) — had `discard_on` declared *before*
     `retry_on StandardError`, so the generic handler always matched
     first and nothing ever reached the specific one. Reordered.
  2. Action Cable was never mounted (`/cable` 404'd) — Rails 8.1's
     auto-mount didn't kick in here for reasons not fully chased down;
     added `mount ActionCable.server => "/cable"` explicitly in
     routes.rb.
- Also fixed: chunk content was truncated to 300 chars on the show page,
  which read as "extraction is incomplete" when it wasn't — direct
  backend inspection confirmed chunking is correct (verified against a
  real resume upload: 808 words, 2 overlapping chunks, zero gaps).
- Pending: user still needs to restart their local server to pick up the
  cable mount fix and confirm live updates actually work end to end in
  the browser (no browser automation tooling available in this
  environment to verify directly). Deferred per user's call — moving to
  embeddings next.

---

## 2026-07-16 (cont. 2) — Text extraction + chunking; deferred a pg segfault

- Shipped: `TextExtractor` (PDF via pdf-reader, plain text), `TextChunker`
  (~500 words, 50-word overlap), `Chunk` model (org_id denormalized for
  future vector-search filtering). `DocumentProcessingJob` now does real
  work, not a stub. 40/40 tests pass, rubocop clean.
- Fixed: `queue` DB connection wasn't inheriting `DATABASE_URL`, silently
  created `solid_queue_*` tables on an unrelated native Postgres on this
  machine instead of our dev DB. Fixed in `database.yml` (`url:` set
  explicitly per connection, not relying on Rails' "only `primary` gets
  it" convention).
- **Deferred**: `bin/jobs` (real Solid Queue supervisor) segfaults in the
  native `pg` gem under concurrent connections. Reverted dev to the
  default `:async` adapter for now — production unaffected. Must fix
  before Phase 6 deploy. See ADR 0006.
- Pending: commit + merge this branch, then continue Phase 3
  (embeddings — the next real increment).

---

## 2026-07-16 (cont.) — Phase 3 start: document upload + machine architecture fix

- Shipped: Active Storage document upload (PDF/text, org-scoped), a
  `DocumentProcessingJob` stub (real text extraction is next), status
  tracking (pending/processing/completed/failed).
- **Major infra fix**: this Mac was migrated from an Intel Mac — Ruby,
  Homebrew, and every native gem were x86_64 running under Rosetta the
  whole project, invisible until Tailwind's CLI crashed on it. Rebuilt
  Ruby 3.3.4 natively for arm64 (OpenSSL built from source, `zlib`/`psych`
  extensions manually relinked against native libs — Homebrew's own
  bottles needed admin rights this account doesn't have). Full reasoning
  belongs in an ADR, not here.
- CI stays disabled (see ADR 0004) — local `rubocop`/`test` both clean.
- Pending: commit + merge this branch, then continue Phase 3 (text
  extraction via `pdf-reader`, chunking, embeddings).

---

## 2026-07-16 — Phase 2 (auth, models, signup, UI)

- Shipped: Rails 8 built-in auth, `Organization`/`Document` models, signup
  (org + first user together), Tailwind UI. PRs #9, #10 (#10 pending CI).
- Fixed: test suite was silently running against the dev DB (`.env`'s
  `DATABASE_URL` loaded in every env) — added `.env.test`. Two UI bugs
  (flash `<div>` vs `<p>`, clobbered Tailwind `stylesheet_link_tag`) —
  see PR #10 description.
- Pending: merge #10, check off Phase 2 in `CLAUDE.md`, start Phase 3
  (upload → chunk → embed → search).

---
