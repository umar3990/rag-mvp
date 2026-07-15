# Notes — AI Knowledge Assistant (RAG MVP)

Running log of what got built, why, and any tradeoffs. One entry per session.
Newest entry on top.

---

## 2026-07-16 — Docker fixed, Postgres/pgvector running, PR workflow live

**What got built:**
- Fixed Docker Desktop: it was installed via a Rosetta-translated (Intel)
  Homebrew at `/usr/local`, so `Hardware::CPU.arch` reported x86_64 on this
  M1 and kept fetching the Intel build, which refuses to run. Removed it
  entirely and installed the arm64 build directly from
  desktop.docker.com — confirmed via `lipo -info` on the binary.
- `docker compose up -d` now works. Remapped the `db` service to host port
  `5433` (not `5432`) because another project's Postgres container
  (`staft-postgres-1`) already owns 5432 on this machine.
- Verified pgvector loads: `CREATE EXTENSION vector;` succeeded, version
  0.8.5.
- Set up the PR-based workflow requested: `CONTRIBUTING.md` (branch
  naming, commit style, workflow steps), `.github/pull_request_template.md`,
  a guarded CI workflow (`.github/workflows/ci.yml` — no-ops until a
  Gemfile exists), and branch protection on `main` via `gh api`
  (PR required, CI must pass, no force-push/delete).
- Added README.md, .env.example, .rubocop.yml (rubocop-rails-omakase,
  Rails 8's default), and two ADRs under docs/decisions/.
- All of the above went through the new PR flow itself
  (`chore/contributor-docs-and-ci` → PR #1) rather than a direct push,
  to prove the workflow works before relying on it.

**Why:**
- Branch protection + required CI check means the workflow is enforced,
  not just documented — matches the "senior engineering standards" ask.

**Not done yet:**
- `rails new` hasn't run yet — still no actual Rails app.
- PR #1 not yet merged (CI should pass since all steps no-op currently).

---

## 2026-07-15 — Personal GitHub account + Rails 8 install

**What got built:**
- New SSH key pair at `~/.ssh/umar_github_personal`, used ONLY for this repo.
- New host alias in `~/.ssh/config`: `github.com-umar-personal` → points at
  `github.com` using that key with `IdentitiesOnly yes` (forces SSH to use
  only this key for that alias, ignoring any other keys loaded in the agent).
- Local (not global) git identity set in this repo:
  `git config --local user.name/user.email` → `Umar / umar.dev4973@gmail.com`.
  Every other repo on this machine still uses the company identity
  (`Omar Farooq / happytenant.ae`) because `--local` only writes to
  `rag-mvp/.git/config`, never `~/.gitconfig`.
- Remote added: `origin` → `git@github.com-umar-personal:umar3990/rag-mvp.git`
  (the host alias, not plain `github.com`, is what routes this repo's
  git traffic through the personal key instead of the default one).
- Verified with `ssh -T git@github.com-umar-personal` → authenticated as
  `umar3990`.
- Installed Ruby 3.3.4 + Rails 8.1.3 into a dedicated rvm gemset
  (`3.3.4@rag-mvp`), separate from the system default (`3.1.2`, Rails 7.1.5)
  used by other projects. `.ruby-version` and `.ruby-gemset` files were added
  to the repo root so rvm auto-switches into this gemset whenever you `cd`
  into `rag-mvp/` (requires rvm's shell integration, which is already on for
  this machine).
- Wrote `docker-compose.yml`: one `db` service on `pgvector/pgvector:pg17`
  (Postgres 17 with the `vector` extension pre-compiled in), exposing 5432,
  with a named volume so data survives container restarts. Pinned to `pg17`
  instead of `latest` so the Postgres version doesn't silently change under
  us later.

**Why:**
- Per-repo SSH alias + `--local` git config is the standard way to run
  multiple GitHub identities from one machine without a global switch that
  could leak a personal commit into a company repo (or vice versa).
- A dedicated rvm gemset avoids clobbering the Ruby/gem setup other projects
  on this machine already rely on (system default is Rails 7.1.5).

**Not done yet:**
- `docker compose up -d` hasn't been run — container not started/verified.
- `rails new` hasn't been run — no Rails app scaffolded yet.
- Nothing has been pushed to GitHub yet (repo is empty on `umar3990/rag-mvp`).

---

## 2026-07-14 — Day 1 kickoff: repo setup

**What got built:**
- Created `rag-mvp/` folder as the actual Rails app repo (kept separate from
  the parent `ai-automation-learning/` folder, which just holds the project
  brief in `CLAUDE.md`).
- Ran `git init` inside `rag-mvp/` — default branch is `master` (git's
  default on this machine; can rename to `main` later if you want).

**Why:**
- Keeping the Rails app in its own subfolder means the git history for the
  app stays clean and only tracks app files, not planning docs.

**Next up (still Day 1 per the plan in CLAUDE.md):**
1. Create an empty GitHub repo and push this one to it, before writing any
   app code — so history starts from commit zero.
2. Add a `docker-compose.yml` using the `pgvector/pgvector` Postgres image
   (Postgres + the `vector` extension baked in, so we don't have to install
   pgvector by hand).
3. `rails new` to scaffold the app.
4. Write a migration enabling the `vector` extension, confirm it connects,
   commit.

**Concepts to understand before Day 1 is "done":**
- Why pgvector instead of a separate vector DB (Pinecone, Weaviate, etc.) —
  short version: one less service to run/pay for/keep in sync, and Postgres
  can join vector search against your normal relational data (e.g. filter
  by `organization_id`) in a single query.
- What `git init` actually sets up locally (a `.git/` folder — no remote yet,
  nothing is on GitHub until we add a remote and push).
