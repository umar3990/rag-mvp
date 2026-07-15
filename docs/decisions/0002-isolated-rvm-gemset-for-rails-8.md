# 2. Isolated rvm gemset for Ruby 3.3.4 / Rails 8

## Status
Accepted

## Context
This machine's default Ruby (via rvm) was 3.1.2 with Rails 7.1.5 installed
globally, used by other projects. Rails 8 requires Ruby >= 3.2.

## Decision
Install Ruby 3.3.4 (already available via rvm) and Rails 8 into a
project-specific gemset (`3.3.4@rag-mvp`), with `.ruby-version` and
`.ruby-gemset` committed to the repo root so rvm auto-switches on `cd`.

## Why
- Avoids upgrading or polluting the global gem set other projects on this
  machine depend on (they're pinned to Rails 7.1.5).
- `.ruby-version` / `.ruby-gemset` make the required environment explicit
  and reproducible for anyone (or any agent) opening this repo.

## Tradeoffs accepted
- Requires rvm's shell integration to be active for auto-switching to work;
  falls back to manually running `rvm use 3.3.4@rag-mvp` otherwise.
