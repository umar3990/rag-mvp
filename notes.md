# Notes — AI Business Automation Platform

Checkpoint log for resuming cold — not documentation, not duplicated from
commit messages/PRs. One short entry per session: what shipped, what's
pending, and only decisions not already captured elsewhere (ADRs, commit
messages). Newest on top. Archive older entries to
`docs/notes-archive/YYYY-MM.md` once this passes ~5 entries.

---

## 2026-07-22 (cont.) — n8n + Gmail setup doc, n8n added to docker-compose

- User has a Gmail account but no n8n account -- clarified that per
  `CLAUDE.md`'s original stack decision, n8n was always meant to run
  self-hosted via Docker, not n8n's paid cloud product, so there's
  nothing to sign up for; "n8n account" just means a local admin login
  inside your own container.
- **Shipped (real code)**: added the `n8n` service to
  `docker-compose.yml` (`docker.n8n.io/n8nio/n8n:latest`, port 5678,
  own named volume) -- validated via `docker compose config`, not
  actually pulled/run yet (large image, no reason to pull it until the
  user is ready to go through the manual setup).
- **Shipped (doc, not code)**: `docs/n8n-gmail-setup.md` -- the full
  manual walkthrough for everything code can't do: Google Cloud OAuth
  client + consent screen for Gmail API access, connecting that
  credential in n8n, building the two n8n workflows (inbound Gmail
  Trigger → HTTP Request to our webhook; outbound Webhook → Gmail send
  → respond), and the `Organization` fields to set
  (`webhook_token` already exists automatically; `n8n_send_webhook_url`/
  `n8n_send_webhook_secret` need setting once the outbound workflow's
  URL and secret are known).
- **Not done yet**: none of this has actually been run through by the
  user yet -- doc is written but unverified against a real n8n
  instance. Next session should walk through it step by step together
  rather than assume it's exactly right on paper (n8n's Gmail node
  field names/expression paths in particular are the most likely thing
  to need adjusting against what a real node's output actually looks
  like).

---

## 2026-07-22 — Outbound send contract: Rails → n8n

- **Decided before building**: n8n owns the actual Gmail send API call,
  not Rails. Rails POSTs to a second, org-specific n8n webhook when a
  draft is approved (`OutboundEmailService` via `SendApprovedReplyJob`,
  enqueued from `MessageReviewsController#approve`); n8n reuses the same
  Gmail credential it already needs to watch the inbox. Rails never
  holds Gmail OAuth at all -- keeps "n8n stays thin" consistent (sending
  an already-approved reply is mechanical plumbing, not a decision) and
  avoids a second OAuth integration living in this app.
  `docs/webhook-contract.md` now documents both directions.
- **Shipped**: `Organization#n8n_send_webhook_url` /
  `#n8n_send_webhook_secret` (per-org config, both nullable -- no real
  n8n send-workflow exists yet to point at). `Message#sent_at` guards a
  retried `SendApprovedReplyJob` against sending the same reply twice,
  same idempotency shape as the inbound side, just the other direction.
- **Honesty check on what's actually verified**: tested via WebMock
  stubs asserting Rails builds and sends the *correct* HTTP request
  (payload shape, `X-Webhook-Token` header) -- there's no real n8n
  instance to round-trip against, so that part stays unverified until a
  real send-workflow exists. No browser re-check this session: this
  change has no new UI surface (approving already worked in the
  browser; it now additionally enqueues a job), so the automated
  WebMock coverage is the right level of verification here, not a
  redundant screenshot pass.
- **Where Phase 5 actually stands**: every piece buildable in this
  codebase is done -- inbound webhook + idempotency, AI Agent step,
  human approval, outbound contract. What's left is entirely outside
  Rails: a Google Cloud OAuth client for n8n's Gmail credential, and
  the real n8n workflows (inbound watch + outbound send) configured
  against `docs/webhook-contract.md`. Not something achievable via code
  changes here -- flagging as the actual remaining work, not silently
  marking Phase 5 done.

---

## 2026-07-21 — Human-approval UI (Reviews)

- **Design decided before building**: collapsed the phase plan's
  "approve as-is / edit / reject / escalate" to three actions --
  Approve, Edit & Approve (the same action: the form always submits
  whatever's in the content field, edited or not), and Reject.
  "Escalate" was dropped as its own action since there's no team
  hierarchy to escalate *to* yet with a single user role -- the
  existing `escalated?` flag already routes low-confidence replies to a
  human by default (nothing auto-sends regardless). No timeout
  automation either -- a pending draft just sits until someone looks;
  revisit only if that's a real problem later.
- **Shipped**: `Message` gained `review_status`
  (pending/approved/rejected, nil for web-sourced chat replies -- those
  show directly to the user asking, no review applies), `reviewed_by`,
  `reviewed_at`. `ReplyGenerator` now sets every email-sourced reply to
  `pending` regardless of `escalated?` -- confident or not, a real
  customer never gets an unreviewed answer. `MessageReviewsController`
  (`/reviews`) lists an org's pending drafts with the customer's
  question, editable draft content, source citations, and an
  escalation badge for context.
- **Real bug caught only by the required browser check, not by the
  test suite**: the Reject button (`button_to`, which renders its own
  `<form>`) was nested inside the Approve `form_with` block. Nested
  `<form>` elements are invalid HTML -- the browser collapses them, so
  clicking Reject actually submitted the enclosing Approve form
  instead. Every controller test passed anyway, because
  `patch reject_review_path(...)` hits the route directly and never
  parses real HTML -- exactly the class of bug this project's working
  agreement requires a browser check for. Fixed by moving the Reject
  button to a sibling of the Approve form, not a child (buttons now
  stack vertically instead of side-by-side -- a minor layout tradeoff
  for correctness).
- **Not done yet**: approved drafts don't actually send via Gmail yet
  (no Gmail API integration exists) -- that's the last piece of Phase 5.

---

## 2026-07-20 — Wired InboundEmailProcessingJob to AnswerGenerator

- **Shipped**: extracted the "retrieve → generate → persist reply"
  logic (previously inline in `MessagesController`) into a shared
  `ReplyGenerator` service, since `InboundEmailProcessingJob` needed the
  exact same step -- one "AI Agent step" per CLAUDE.md's Phase 5 plan,
  two triggers (chat UI, inbound email), not two implementations.
  `MessagesController` simplified to a single call;
  `InboundEmailProcessingJob` is no longer a stub.
- Verified with a real (non-stubbed) Ollama round trip via an isolated
  temp organization, same discipline as previous sessions: real email
  in → job → grounded draft reply with correct source citation, cleaned
  up after.
- **Still not built**: the draft reply is persisted but there's no
  approval UI to see or act on it yet, and nothing sends a reply via
  Gmail. Those are the next two increments.

---

## 2026-07-17 (cont. 2) — Phase 5 start: webhook contract + idempotency

- **Decided**: org identification for the inbound Gmail webhook is a
  per-organization secret token in the URL
  (`POST /webhooks/gmail/:webhook_token`), not a header + org id, not
  anything parsed from the email itself — same pattern Stripe/GitHub use
  for webhooks. `Organization#webhook_token` via Rails' `has_secure_token`.
  Full reasoning + payload shape + response codes written up in the new
  `docs/webhook-contract.md` (first real doc in that file, per the phase
  plan's "write it when there's something real to document" rule).
- **Idempotency key**: Gmail's `Message-Id` header, stored as
  `messages.gmail_message_id` under a DB unique index — deliberately a
  DB constraint, not just an application-level existence check, since
  only the DB actually closes the race where two webhook deliveries for
  the same email arrive close enough together to both pass an
  existence check before either inserts.
- **Schema**: `Conversation` gained `source` (web/email),
  `from_email`, `gmail_thread_id` (unique per organization), and
  `user_id` became optional (an email-originated conversation has no
  app user until a human approves a reply — that step doesn't exist
  yet). `Message` gained `gmail_message_id`.
- **A real design conflict found by the test suite, not guessed at
  design time**: first pass added a model-level `uniqueness` validation
  on `gmail_thread_id` *in addition to* the DB unique index, reasoning
  "defense in depth." That was wrong here specifically —
  `GmailWebhooksController` uses `create_or_find_by!` (attempt insert,
  fall back to find on a unique-index conflict) precisely so a second
  email in an *existing* thread — the ordinary case, not a race — finds
  the conversation instead of erroring. The blocking validation raised
  before the DB was ever touched, so every normal second-email-in-a-thread
  request 422'd. Removed the validation; the DB index is the only place
  that invariant is enforced now. Two failing tests caught this
  immediately once written.
- **Shipped**: `GmailWebhooksController` (verify token → check required
  fields → find-or-create the `Conversation` → write the inbound
  `Message` immediately, audit-trail-first → enqueue
  `InboundEmailProcessingJob` → respond fast) and that job as a
  deliberate stub — generating the actual reply via `AnswerGenerator` is
  scoped as the next increment, not this one.
- **Not done yet**: the job doesn't call `AnswerGenerator` yet, there's
  no approval UI, and nothing sends a reply. n8n itself also isn't set
  up — this only covers the Rails side of the contract.

---

*Entries older than this point moved to
`docs/notes-archive/2026-07.md` (Phase 4's chat UI through Phase 2) to
keep this file short — see that file for anything from 2026-07-17 and
earlier not covered by the entries above.*
