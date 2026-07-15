# Notes — AI Business Automation Platform

Running log of what got built, why, and any tradeoffs. One entry per
session. Newest entry on top.

Older entries are archived under `docs/notes-archive/` once this file
grows past a few sessions, to keep it cheap to read — see
`docs/notes-archive/2026-07.md` for everything before this point.

---

## 2026-07-16 (cont. 4) — Phase 2: signup + Tailwind UI [CHECKPOINT]

**What got built (branch `feat/signup-and-ui`, not yet merged):**
- Added `tailwindcss-rails` — signup, sign-in, password-reset, and the
  placeholder dashboard now have a real styled UI (card-style forms, nav
  bar, flash messages) instead of bare unstyled HTML.
- `RegistrationsController` (`/registration`) — Rails 8's built-in auth
  generator only ships sign-in/password-reset, not signup, by design (it
  assumes you decide how accounts get created). Here, signup creates an
  `Organization` and its first `User` together in one form/transaction
  (relies on `has_many` autosave — building `@organization.users.new(...)`
  then calling `@organization.save` saves and validates both records
  together; confirmed by test, not just assumed).
- Found and fixed two real bugs while verifying (not just trusting green
  tests):
  1. Flash messages rendered in a `<p>` tag; the generated
     `PasswordsControllerTest` asserts `assert_select "div", ...` — 5
     tests failed until fixed to `<div>`.
  2. The Tailwind installer inserts a `stylesheet_link_tag "tailwind"`
     into the layout; I'd overwritten the whole layout file with `Write`
     afterward and clobbered that insertion, so the compiled CSS was
     never actually linked — page had the right classes but zero styling.
     Caught by checking the served CSS for our actual utility classes
     (`grep` for `.rounded-md` etc. in the response), not just "does the
     page 200."
- Fixed a stale leftover: the layout's `<title>`/meta still said "Rag Mvp
  Scaffold" from before the app was renamed on Day 1 — missed in that
  earlier rename pass. Now "RAG Knowledge Assistant".

**Why:**
- Verifying "does it actually render styled" required checking the served
  asset content, not just HTTP 200 + passing tests — the CSS-not-linked
  bug would have shipped invisibly past both.

**State right now:**
- All local checks pass: 23/23 tests, rubocop clean, system tests clean.
- Manually confirmed via `curl`: signup page renders, compiled Tailwind
  CSS is served and contains the classes the forms use.
- **Not yet committed.** Next action: commit, push, open PR, watch CI,
  merge. Then update `CLAUDE.md`'s progress tracker to check off Phase 2.

**A fresh session can resume from here** by reading this entry + running
`git status` on `feat/signup-and-ui`.

---
