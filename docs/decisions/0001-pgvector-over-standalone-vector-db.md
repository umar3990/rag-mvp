# 1. Use pgvector instead of a standalone vector database

## Status
Accepted

## Context
Vector search for RAG retrieval needs somewhere to store and query
embeddings. Options considered: a dedicated vector DB (Pinecone, Weaviate,
Qdrant) or Postgres with the pgvector extension.

## Decision
Use Postgres + pgvector, via the `neighbor` gem.

## Why
- One database to run, back up, and pay for instead of two.
- Vector search can be joined against normal relational data in a single
  query — e.g. filter nearest-neighbor results by `organization_id` without
  round-tripping between two systems.
- `pgvector/pgvector` Docker image ships the extension pre-compiled, so
  there's no separate install step.

## Tradeoffs accepted
- pgvector's ANN (approximate nearest neighbor) indexes are less mature
  than a purpose-built vector DB's at very large scale (tens of millions of
  vectors+). Not a concern for an MVP's document corpus size.
