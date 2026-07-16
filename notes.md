# Notes — AI Business Automation Platform

Checkpoint log for resuming cold — not documentation, not duplicated from
commit messages/PRs. One short entry per session: what shipped, what's
pending, and only decisions not already captured elsewhere (ADRs, commit
messages). Newest on top. Archive older entries to
`docs/notes-archive/YYYY-MM.md` once this passes ~5 entries.

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
