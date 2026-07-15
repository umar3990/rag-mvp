# Notes — AI Business Automation Platform

Checkpoint log for resuming cold — not documentation, not duplicated from
commit messages/PRs. One short entry per session: what shipped, what's
pending, and only decisions not already captured elsewhere (ADRs, commit
messages). Newest on top. Archive older entries to
`docs/notes-archive/YYYY-MM.md` once this passes ~5 entries.

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
