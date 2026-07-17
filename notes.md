# Notes — AI Business Automation Platform

Checkpoint log for resuming cold — not documentation, not duplicated from
commit messages/PRs. One short entry per session: what shipped, what's
pending, and only decisions not already captured elsewhere (ADRs, commit
messages). Newest on top. Archive older entries to
`docs/notes-archive/YYYY-MM.md` once this passes ~5 entries.

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
