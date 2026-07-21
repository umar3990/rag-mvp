# Notes — AI Business Automation Platform

Checkpoint log for resuming cold — not documentation, not duplicated from
commit messages/PRs. One short entry per session: what shipped, what's
pending, and only decisions not already captured elsewhere (ADRs, commit
messages). Newest on top. Archive older entries to
`docs/notes-archive/YYYY-MM.md` once this passes ~5 entries.

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

## 2026-07-17 (cont.) — Phase 4: chat UI, and a real Rails association bug caught by actually looking

- **Shipped**: `Conversation`/`Message`/`MessageSource` models
  (org-wide knowledge base per conversation, not per-document — matches
  how `ChunkRetriever`/`AnswerGenerator` already scope), `ConversationsController`
  + `MessagesController`, Turbo-Stream chat UI reusing the existing
  Tailwind conventions. Escalated replies get distinct amber styling;
  answered replies show clickable source-document citations built from
  `AnswerGenerator`'s own retrieved chunks (not the model's self-reported
  citations, same reasoning as before).
- **Real bug caught by browser-testing instead of trusting the test
  suite**: `@message = @conversation.messages.new` in
  `ConversationsController#show` looked idiomatic but is wrong —
  building an unsaved record through a `has_many` association appends it
  to that association's already-loaded in-memory array, so
  `render @conversation.messages` on the same page rendered the blank
  scratch form-record as a phantom empty message bubble. Invisible to
  the controller/model test suite (nothing asserted on the *absence* of
  a bubble); only showed up as a literal empty white box in a real
  screenshot. Fixed by building `Message.new(conversation: @conversation)`
  instead, unassociated. Same latent smell existed in
  `MessagesController#create`'s `@blank_message` — fixed there too even
  though it wasn't yet causing a visible bug in that action.
- **Verified end-to-end via headless Chromium** (Playwright, driven
  directly — no `chromium-cli` in this environment, installed
  `playwright` fresh into a scratch dir instead): signed in, started a
  conversation, asked a real question against a real document → got a
  grounded answer with a working source-document link; asked an
  off-topic question → got the escalation message with amber styling,
  not a hallucinated answer. Zero console errors either time.
- **Process note**: built the verification org/user/document via
  `bin/rails runner` rather than reusing any existing organization —
  learned the hard way in the previous session that `Organization.first`
  silently lands on real dev data if any exists. Fully cleaned up
  (org/user/document/chunks destroyed) after screenshots were captured.
- **What's still not built**: no human-approval step exists yet
  (Phase 5) — escalation currently just tells the user honestly that
  nothing confident was found, without promising a human will follow up,
  since that hand-off doesn't exist. Phase 5 is next: Gmail → n8n →
  webhook → this same `AnswerGenerator` pipeline, but with a real
  approval UI before anything sends.

---

## 2026-07-17 — Retrieval + generation: Phase 3's RAG core is functionally done

- **Shipped `ChunkRetriever`**: embeds a question, queries `Chunk` scoped
  to one organization first (never leaks another org's data even on a
  perfect semantic match), ordered by pgvector cosine distance via
  `neighbor`. Tests use hand-crafted orthogonal/opposite unit vectors for
  deterministic ordering assertions, separate from testing whether
  real embeddings are semantically sensible (not this code's job to
  verify) — that was checked once by hand against real Ollama data
  instead (return-policy question correctly ranked the return-policy
  chunk closest).
- **Decision, chat completion also local via Ollama**: no hosted provider
  (Anthropic, OpenAI) has a genuinely free/no-card API tier — the paid
  Claude.ai subscription is a separate product/billing system from the
  API and doesn't grant API credits. Given the hard $0/no-card
  constraint, extended the same exception already made for embeddings to
  chat completion. Pulled `llama3.2:3b` (2GB) alongside
  `nomic-embed-text` on the same native Ollama install. `CLAUDE.md`
  updated in place (Stack + Deliberately-deferred sections) rather than
  a separate ADR, since it's the same decision already recorded there
  for embeddings, just extended.
- **Shipped `ChatCompletionService`** (same shape as `EmbeddingService`,
  posts to Ollama's `/api/chat`) and **`AnswerGenerator`**, which ties
  both together: retrieve top-k chunks, check the closest match's cosine
  distance against a threshold (0.6, a tunable judgment call, not a
  formula) *before* calling the chat model, and only generate if
  something's actually relevant — otherwise returns `escalated?: true`
  with no LLM call spent. Sources come from the chunks *we* retrieved,
  not the model's own citations, since that's the more trustworthy
  approach for a flow with a human-approval step downstream.
  Verified end-to-end by hand: a return-policy question got a grounded
  answer citing the right document; an off-topic question (weather on
  Mars) correctly escalated instead of hallucinating.
- **Near-miss caught while smoke-testing**: an early test script did
  `Organization.first` instead of creating an isolated test org, which
  silently landed on the user's real dev organization (real uploaded
  documents already in this dev DB) — a "Smoke Test" document briefly
  existed there before being caught and deleted. Fixed by always
  creating a throwaway `Organization` for manual smoke tests going
  forward, never reusing `.first`.
- **What's still not built**: Phase 3's pieces are all done at the
  service layer (`EmbeddingService`, `ChunkRetriever`,
  `ChatCompletionService`, `AnswerGenerator`), but there's no UI or
  controller action calling `AnswerGenerator` yet — that's Phase 4 (the
  chat interface), which doubles as the test surface before Gmail is
  ever wired in per the phase plan.

---

## 2026-07-16 (cont. 5) — Ollama moved off Docker entirely, running native + persistent

- **Pivot**: dropped Docker for Ollama. After reboot, Docker Desktop's own
  VM disk came back corrupted (`input/output error` on overlay2, then
  `error creating temporary lease` on the containerd metadata db) — a
  fresh `docker compose down`/restart-Docker-Desktop cycle fixed the
  daemon, but the resulting container still failed with
  `exec format error` running `nomic-embed-text`, meaning the 2.66GB image
  layer itself got corrupted mid-pull during the earlier crash despite
  Docker reporting "Pull complete". Rather than debug Docker Desktop
  further, switched to running Ollama natively.
- **Installed**: the official prebuilt universal (x86_64 + arm64) binary
  from `github.com/ollama/ollama` releases, unpacked to
  `~/ollama-native/` — not the Homebrew bottle (Homebrew's `ollama` is
  Intel-only on this machine and would run under Rosetta, same class of
  problem as the Ruby arm64 saga; Ollama also needs native arm64 for
  Metal GPU acceleration, which Rosetta can't provide).
  `ollama pull nomic-embed-text` re-run natively (fast — no container
  layer overhead), confirmed working via
  `curl localhost:11434/api/embeddings`.
- **Made persistent**: `~/Library/LaunchAgents/com.ollama.serve.plist`
  (`RunAtLoad` + `KeepAlive`) — starts on login, restarts if killed.
  Verified by manually killing the process and confirming launchd
  respawned it within seconds. Logs at
  `~/ollama-native/logs/ollama.{out,err}.log`.
  `docker-compose.yml`'s `ollama`/`ollama-pull` services and the
  `ollama_data` volume removed — Rails still talks to the same
  `localhost:11434` either way, so no app code changes needed for this
  pivot.
- **Fixed a real bug found while smoke-testing**: `EmbeddingService.call`
  raised `NameError: uninitialized constant Net::HTTP` — Rails
  autoloading doesn't cover Ruby stdlib, needed explicit
  `require "net/http"` / `require "json"` at the top of the file.
- **Mid-session incident (self-inflicted, flagged to user)**: an abandoned
  `brew uninstall ollama` attempt triggered Homebrew's default
  `autoremove` and deleted 15 "orphaned" formulae (`llvm` 1.7GB,
  `python@3.12`, `python@3.13`, `open-mpi`, `protobuf@29`, `z3`, `unbound`,
  others) — Homebrew only tracks formula-to-formula deps, so anything the
  user ran directly (not via a project's own venv/pyenv) is gone until
  reinstalled. User hasn't confirmed yet whether any of these are needed
  back.
- **Next steps on resume**: `EmbeddingService.call` verified end-to-end
  through `bin/rails runner`, returns a real 768-dim vector. Next real
  increment is wiring it into `DocumentProcessingJob` for actual documents
  (job already calls it per chunk per the previous entry) and testing
  the full chunk → embed → vector-search flow, not just the isolated
  service call.

---

## 2026-07-16 (cont. 4) — Embeddings: local via Ollama, $0 cost (IN PROGRESS, interrupted by Mac restart)

- Decision: embeddings run locally via Ollama (`nomic-embed-text`, 768-dim)
  instead of a paid API — cost-driven, discussed as a deliberate exception
  to the "no local LLMs" deferral (that deferral was about chat models;
  this is an embedding model, much lighter, and the driver is $0 cost).
  Containerized into `docker-compose.yml` (not just a bare-metal local
  install) so `docker-compose up` covers it, matching how `db` is already
  run — Rails itself still runs on the host via `bin/rails server`, so it
  reaches Ollama over HTTP at `localhost:11434`.
- Shipped (code side, done): `docker-compose.yml` gained `ollama` (server)
  + `ollama-pull` (one-shot `ollama pull nomic-embed-text`, safe to
  re-run) services. `.env`/`.env.example`/`.env.test`/`.env.test.example`
  gained `OLLAMA_URL` + `OLLAMA_EMBEDDING_MODEL`. Migration
  `AddEmbeddingToChunks` (768-dim `vector` column via `neighbor`, run
  against both dev and test DBs). `Chunk` model:
  `has_neighbors :embedding, dimensions: 768`. New
  `app/services/embedding_service.rb` (`EmbeddingService.call(text)` →
  POSTs to Ollama's `/api/embeddings`, returns the float array).
  `DocumentProcessingJob` now calls it per chunk before saving.
- **Blocked**: `docker compose up -d ollama ollama-pull` hit an
  `unexpected EOF` mid-pull first try (the `ollama/ollama` image is ~2.6GB,
  bigger than expected), retried and that succeeded, but then the Docker
  Desktop daemon itself stopped responding (`docker.sock` missing even
  though some Docker processes were still alive) — reopening the app via
  `open -a Docker` didn't visibly recover it in time, so the user is
  rebooting the Mac to clear it up.
- **Next steps on resume**: after reboot, confirm Docker Desktop is
  healthy (`docker ps`), run `docker compose up -d ollama ollama-pull`
  (should be fast now — the ~2.6GB image layers are already pulled and
  cached locally), confirm the model pulled
  (`docker compose logs ollama-pull`), then smoke-test
  `EmbeddingService.call("test")` in `bin/rails console` against the
  running container before trusting it inside `DocumentProcessingJob`.
  Nothing about the Rails-side code needs to change — this is purely
  "get the container running again."
- Note: ran Rails commands in this session via
  `GEM_HOME=~/.rvm/gems/ruby-3.3.4@rag-mvp`,
  `GEM_PATH=$GEM_HOME:~/.rvm/gems/ruby-3.3.4@global`,
  `PATH=~/.rvm/rubies/ruby-3.3.4/bin:$GEM_HOME/bin:$PATH` rather than
  sourcing RVM's shell function — plain `rvm use` isn't available
  non-interactively in this environment; bin/rails otherwise picks up the
  wrong Ruby (system default 3.1.2, x86_64) and errors on gem resolution.

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

*Entries older than this point moved to
`docs/notes-archive/2026-07.md` (Phase 2, and Phase 3's document-upload
start) to keep this file short — see that file for anything from
2026-07-16 and earlier not covered by the entries above.*
