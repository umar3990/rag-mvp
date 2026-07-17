# AI Business Automation Platform — Project Brief

Read this file fully before writing any code. This is the persistent plan for the project — update the progress tracker at the end of each session so future sessions pick up where the last one left off.

## Vision (long-term context — not the current build target)

The long-term idea is a platform that connects business tools (email, CRM,
calendars, docs), understands business context via AI, executes workflows,
and keeps humans in the loop only where it matters — reducing manual
repetitive work for small/medium businesses.

Full platform shape (for context, not what we're building right now):
- **Frontend**: a dashboard app (React/Next.js) — not started, not needed yet.
- **Business platform**: Rails — auth, orgs, billing, workflow config, audit logs.
- **Automation engine**: n8n — thin relay/trigger layer between external
  systems (Gmail, Slack, CRM, calendars) and the Rails app.
- **AI layer**: one or more LLM providers — understanding, retrieval,
  generation, decisioning.
- **Data layer**: Postgres (system of record), pgvector (RAG), object
  storage (documents).

This vision stays in this file as direction, not as a build queue — see
"Deliberately deferred" below for what we are explicitly not building yet
and why.

## Goal (what we're actually building)

An **AI Customer Support Agent**, end to end:

```
Gmail (new email)
      |
n8n (thin relay — no business logic here)
      |
Rails webhook (idempotent, hands off to a background job, returns fast)
      |
AI Agent step (RAG-augmented response using our own knowledge base)
      |
Confidence check — low similarity/confidence skips straight to human
      |
Draft response saved
      |
Human approval UI (Hotwire) — approve as-is / edit / reject / escalate
      |
Send reply (threaded, same Gmail conversation)
      |
Full history saved (written incrementally from the first step, not just at the end)
```

This *is* the RAG MVP, not a replacement for it — the "AI Agent" step is
exactly the document-upload/chunk/embed/retrieve pipeline originally
scoped, just triggered by an inbound email instead of a chat box, with a
human-approval step before anything gets sent. Everything from the
original RAG plan (chunking, embeddings, vector search, source citations)
is still built, in the same order — it just isn't the final UI.

Two things matter equally: shipping this end to end, and the person
building it (a Ruby/Rails dev learning AI engineering, currently job
hunting) actually understanding every piece, not just accepting generated
code.

## Working agreement

- **Concept before code.** Before building something that introduces a new
  concept (embeddings, chunking strategy, vector search, tool-calling vs.
  single-shot RAG, idempotent webhooks, human-in-the-loop approval,
  background job design), explain the concept in plain terms first, discuss
  it, *then* build it. Implementation without the concept landing first is
  a miss, even if the code works.
- Before applying non-trivial generated code, explain what it does, line by
  line if it's not obvious.
- At the end of each session, update the progress tracker below and append
  a short entry to `notes.md` in the repo root: what got built, why, and
  any tradeoff decided.
- Record any non-obvious technical decision as a numbered ADR in
  `docs/decisions/` (see `CONTRIBUTING.md`) — pgvector choice and this
  plan pivot already have one each.
- If asked "what would break if X were removed," answer honestly — this is
  a comprehension check, not just execution.
- Changes land via PR per `CONTRIBUTING.md` (branch protection is on for
  `main` — no direct pushes).

## Stack (Rails 8 specifics)

- Rails 8, using built-ins where possible: **Solid Queue** for background
  jobs (no Redis/Sidekiq needed) — this is what makes the webhook-ack /
  background-process split work without extra infra
- PostgreSQL + **pgvector** extension for vector search, via the `neighbor`
  gem (already set up — Day 1)
- Active Storage for document upload (knowledge base ingestion)
- `pdf-reader` gem for text extraction
- **One** LLM provider — decided: Ollama, running natively on the host
  (not Docker — see notes.md), for both embeddings (`nomic-embed-text`)
  and chat completion (`llama3.2:3b`). Cost-driven: a genuinely free,
  no-card API tier doesn't exist at any hosted provider, so this is the
  deliberate exception to "Local LLMs" below, extended from embeddings to
  chat completion for the same reason. Multi-provider switching is
  explicitly deferred, see below.
- Hotwire/Turbo for the UI (human-approval screen, no separate frontend)
- n8n (Docker) — thin trigger/relay only; Gmail → webhook. All decision
  logic lives in Rails, not n8n, so it's testable and lives in git.
- Gmail API for receiving + sending (threaded replies via
  `In-Reply-To`/`References` headers)
- Deploy via Kamal (built into Rails 8) — decided already, no need to
  revisit at the end like the old plan assumed

## Deliberately deferred (vision, not backlog clutter — revisit later)

- **React/Next.js frontend** — Hotwire covers the human-approval UI we
  actually need; a second frontend stack is weeks of cost for no signal
  given the goal is a Rails/AI-engineering portfolio piece.
- **Multi-tenant billing, subscription plans** — `Organization` model
  exists for future-proofing but there's no billing logic.
- **Multiple LLM provider switching** — pick one now, add provider
  abstraction only if there's a real reason to.
- **Executive analytics dashboard** — no dashboard until the core loop
  works end to end.
- **Lead qualification agent, additional integrations** (Slack, CRM,
  Calendar, other inboxes beyond Gmail) — same shape as the support agent,
  build once the pattern is proven once.
- **True tool-calling agent** (checking order status, account lookups,
  multi-step reasoning) — MVP's "AI Agent" step is one RAG-augmented LLM
  call plus a confidence/escalate check, not an agentic loop with tools.
  Upgrade to tool-calling only after the simple version is working and its
  limits are actually felt.
- **Local LLMs** — ~~not until there's a concrete reason (cost, latency,
  privacy) to need one~~ superseded: cost turned out to be that concrete
  reason for both embeddings and chat completion (see Stack above). Still
  applies to anything beyond those two calls.

## Phase Plan

### Phase 1 — Infrastructure ✅ done
`git init`, GitHub repo (PR workflow + branch protection live), Docker
Compose with `pgvector/pgvector`, `rails new`, vector extension migration
confirmed working. See `notes.md` for the full log (including the Docker
arm64/Rosetta debugging saga).

### Phase 2 — Core Rails platform
`User`/`Organization`/`Document` models, basic auth. Concepts: why an
`Organization` scoping model even for a single-tenant MVP (keeps the door
open, costs nothing now).

### Phase 3 — Knowledge base (RAG core)
Same substance as the original plan, unchanged:
- Document upload via Active Storage, a Solid Queue job kicked off on upload.
- `pdf-reader` text extraction, chunk into ~500-token pieces, `Chunk` model.
- Call the embeddings API per chunk, store vectors via `neighbor`.
- Nearest-neighbor query for top-k relevant chunks given a question.
- Build a prompt from retrieved chunks, call chat completion, return an
  answer with source citations.

Concepts: chunking strategy tradeoffs, what an embedding actually is,
cosine similarity vs. other distance metrics, why citations matter for
trust.

### Phase 4 — Human-facing chat UI
Turbo-based upload page + chat interface, `Conversation`/`Message` models.
Doubles as the internal test surface for the RAG core before wiring it to
email — you should be able to ask it questions directly before an email
ever touches it.

### Phase 5 — Automation pipeline (the new work)
- Gmail inbound trigger via n8n → Rails webhook. Idempotent (dedupe by
  Gmail message ID), returns fast, hands off to a Solid Queue job.
- AI Agent step reuses the Phase 3 knowledge base. Confidence check: low
  retrieval similarity skips generation and routes straight to human.
- Draft response persisted, not sent — `Conversation`/`Message` history
  written incrementally from the moment the email arrives, not just at the
  end, so there's an audit trail even if something fails midway.
- Human approval UI (extends Phase 4's UI): approve as-is, edit, reject,
  escalate. Define what happens on timeout (no approval within N hours).
- Send reply via Gmail API, threaded to the original conversation.

Concepts: idempotency/dedup for webhooks, why n8n should stay thin,
background job design, human-in-the-loop patterns, audit-trail-first data
modeling.

**Docs to add in this phase** (not before — write them when there's
something real to document, not speculatively):
- Export n8n workflow(s) as JSON into `automation/n8n/` in the repo, with a
  short README covering trigger setup (Gmail push notification / webhook
  URL) and which credentials it references by name (never by value).
- `docs/webhook-contract.md` — the Rails endpoint n8n calls: auth method,
  payload shape, idempotency key, response codes. This is the seam between
  two systems, worth documenting precisely.

### Phase 6 — Polish, deploy, write-up
Deploy via Kamal. README with architecture diagram. Demo recording (show
an actual email going in and a reply coming out, with the approval step).
Clean commit history.

**Docs to add in this phase:**
- `docs/architecture.md` with a rendered diagram (mermaid) of the full
  pipeline, for the README and for interview walkthroughs.

## Progress Tracker

- [x] Phase 1 — Infrastructure
- [x] Phase 2 — Core Rails platform (auth, User/Organization/Document)
- [ ] Phase 3 — Knowledge base (upload → chunk → embed → search → RAG answer)
- [ ] Phase 4 — Human-facing chat UI
- [ ] Phase 5 — Automation pipeline (Gmail → n8n → Rails → agent → approval → send)
- [ ] Phase 6 — Polish, deploy, write-up

## Backlog (post-MVP, see "Deliberately deferred" above for the why)

Lead Qualification Agent, additional n8n integrations (Slack, CRM,
Calendar, other inboxes), multi-tenant billing, multiple LLM providers,
executive analytics dashboard, tool-calling agent upgrade, React/Next.js
frontend, local LLMs.
