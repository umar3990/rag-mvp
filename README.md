# AI Knowledge Assistant (RAG MVP)

Upload documents, ask questions, get answers with citations pulled from
those documents. Rails 8 + pgvector. See `CLAUDE.md` for the full project
brief and day-by-day build plan; see `notes.md` for a running log of what's
been built and why.

## Requirements

- Ruby 3.3.4 (managed via rvm, see `.ruby-version` / `.ruby-gemset`)
- Docker (for Postgres + pgvector)

## Setup

```bash
# Postgres with pgvector, via Docker
docker compose up -d

# Ruby deps (once the Rails app is scaffolded)
bundle install

# create + migrate the database
bin/rails db:setup
```

Copy `.env.example` to `.env` and fill in your own API keys — never commit
`.env`.

## Running

```bash
bin/rails server
```

## Status

Day 1 (environment setup) in progress. See the Progress Tracker in
`CLAUDE.md` for where the project currently stands.
