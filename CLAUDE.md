# AI Knowledge Assistant (RAG MVP) — Project Brief

Read this file fully before writing any code. This is the persistent plan for the project — update the progress tracker at the end of each session so future sessions pick up where the last one left off.

## Goal

Build a Rails 8 app where a user uploads documents, they get chunked and embedded, and questions get answered from those documents with citations (RAG — retrieval-augmented generation). This is a scoped-down slice of a larger AI Business Automation Platform idea, chosen because it's self-contained and teaches the core AI/automation skills fastest.

Two things matter equally here: shipping the MVP, and the person building it (a Ruby/Rails dev learning AI engineering) actually understanding every piece — not just accepting generated code. Default to explaining before generating. When you write non-trivial code, explain what it does and why before or alongside applying it.

## Stack (Rails 8 specifics)

- Rails 8, using built-ins where possible: **Solid Queue** for background jobs (no Redis/Sidekiq needed), Solid Cache if caching comes up
- PostgreSQL + **pgvector** extension for vector search, via the `neighbor` gem
- Active Storage for document upload
- `pdf-reader` gem for text extraction
- OpenAI or Anthropic API for embeddings + chat completion (key from console.anthropic.com or platform.openai.com)
- Hotwire/Turbo for the UI — no separate frontend framework for the MVP
- n8n (Docker) for exactly one automation, added near the end
- Deploy via Kamal (built into Rails 8) or Fly.io/Render — decide at day 10

## Scope boundaries (don't build these yet)

Multi-tenant billing, multiple LLM provider switching, executive dashboards, CRM/email/Slack integrations beyond one n8n demo workflow, a separate frontend app. These are backlog, not MVP.

## Day-by-Day Plan

- **Day 1 — Environment.** `git init`, empty GitHub repo pushed first. Docker Compose with a `pgvector/pgvector` Postgres image. `rails new`. Migration enabling the `vector` extension. Confirm it works. Commit.
- **Day 2 — Auth & scaffolding.** Basic auth (Devise or hand-rolled), `User`/`Organization`/`Document` models.
- **Day 3 — Document upload.** Active Storage for PDF/txt, a Solid Queue job kicked off on upload.
- **Day 4 — Text extraction & chunking.** `pdf-reader` to extract text, chunk into ~500-token pieces, store as `Chunk` records linked to `Document`.
- **Day 5 — Embeddings.** Call the embeddings API per chunk, store vectors via `neighbor`'s pgvector column.
- **Day 6 — Vector search.** Embed a user question, run nearest-neighbor query for top-k relevant chunks.
- **Day 7 — RAG generation.** Build a prompt from retrieved chunks + question, call chat completion, return an answer with source citations.
- **Day 8 — Chat UI.** Turbo-based upload page + chat interface, `Conversation`/`Message` models for history.
- **Day 9 — One automation.** n8n webhook triggered on document upload, posts a Slack/email notification.
- **Day 10 — Polish, deploy, write-up.** Deploy. README with architecture diagram. Demo recording. Clean commit history.

## Working agreement

- Before applying non-trivial generated code, explain what it does, line by line if it's not obvious.
- At the end of each session, update the progress tracker below and append a short entry to `notes.md` in the repo root: what got built, why, and any tradeoff decided (e.g. chunk size, why pgvector over a standalone vector DB).
- If asked "what would break if X were removed," answer honestly — this is a comprehension check, not just execution.

## Progress Tracker

- [ ] Day 1 — Environment
- [ ] Day 2 — Auth & scaffolding
- [ ] Day 3 — Document upload
- [ ] Day 4 — Text extraction & chunking
- [ ] Day 5 — Embeddings
- [ ] Day 6 — Vector search
- [ ] Day 7 — RAG generation
- [ ] Day 8 — Chat UI
- [ ] Day 9 — One automation (n8n)
- [ ] Day 10 — Polish, deploy, write-up

## Backlog (post-MVP)

AI Customer Support Agent, AI Lead Qualification Agent, multi-tenant billing, multiple LLM providers, executive analytics dashboard, additional n8n integrations (Gmail, Slack, Calendar, CRM).
