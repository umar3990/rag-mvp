# Learning Log

This file is for *understanding*, not resuming — `notes.md` is the terse
checkpoint log; this is the teaching version. Each section walks through
what we built, why, and how the actual code works, with real snippets
from this repo. Read alongside the files it references.

---

## Phase 1 — Infrastructure

**What:** Docker running Postgres with the `pgvector` extension, a Rails
8 app connected to it, one migration.

**Why Docker for the database specifically:** Postgres needs to run
somewhere. Instead of installing it directly on your Mac (version
conflicts with other projects, manual upgrades), Docker runs it in an
isolated container — `docker-compose.yml` describes exactly one thing:
"run this Postgres image, on this port, with this data volume." Delete
the container, run `docker compose up -d` again, you're back to a clean
database. Nothing about your actual machine changed.

**Why pgvector, not a separate vector database:** Later phases need to
store *embeddings* (more below) and search them by similarity. You could
run a dedicated vector database (Pinecone, Weaviate) alongside Postgres,
but that's a second system to run, pay for, and keep in sync. `pgvector`
is a Postgres extension — it adds a `vector` column type and similarity
search directly inside the database you already have. One query can join
a vector search against your normal relational data (e.g. "find similar
documents, but only within this organization").

**The one migration so far** (`db/migrate/..._install_neighbor_vector.rb`):
```ruby
class InstallNeighborVector < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"
  end
end
```
A *migration* is a versioned, ordered instruction for changing the
database's structure. This one doesn't create a table — it just turns on
the `vector` extension inside Postgres, a one-time setup step, the
prerequisite for every migration after it that adds a `vector` column.

---

## Phase 2 — Authentication, core models, signup, UI

### Authentication — how "logging in" actually works

We used Rails 8's *built-in* auth generator (`bin/rails generate
authentication`), not Devise (the popular gem). It generated real,
readable files instead of hiding the logic in a gem:

- **`app/models/user.rb`** — `has_secure_password` is the core line. It
  adds a `password` and `password_confirmation` virtual field, and
  handles hashing: when you call `User.create!(password: "secret")`,
  Rails never stores `"secret"` — it stores a one-way hash
  (`password_digest` column) via the `bcrypt` gem. There's no way to
  reverse a hash back into the original password, even for us. Logging in
  re-hashes the entered password and compares hashes.
- **`app/models/session.rb`** — a `Session` is a *database row*, not just
  a cookie. Each time you sign in, a new `Session` record is created
  (`user_id`, `ip_address`, `user_agent`). The browser only holds a
  signed cookie pointing at that row's ID. This is why signing out on one
  device doesn't need to invalidate a JWT or shared secret — you just
  delete that one row.
- **`app/controllers/concerns/authentication.rb`** — a *concern* is
  shared controller behavior, `include`d into `ApplicationController`
  (see line 2 of `app/controllers/application_controller.rb`). Because
  every controller inherits from `ApplicationController`, this one
  `before_action :require_authentication` line means **every page in the
  app requires login by default** — you have to explicitly opt out
  (`allow_unauthenticated_access`) for pages like the sign-in form itself
  where requiring login would be circular.

### Why signup needed to be hand-built

The generator deliberately stops at sign-in + password reset — it has no
opinion on *how accounts get created* (self-serve signup? invite-only?
SSO?). That's a product decision, not a technical default. We built
`app/controllers/registrations_controller.rb` to answer it: signup
creates an `Organization` and its first `User` *together*, in one form.

```ruby
def create
  @organization = Organization.new(organization_params)
  @user = @organization.users.new(user_params)

  if @organization.save
    start_new_session_for @user
    redirect_to after_authentication_url
  ...
```

The interesting bit: `@organization.save` saves *both* records. Building
`@user` via `@organization.users.new(...)` (rather than `User.new(...)`)
links them in memory. Rails' `has_many` association has "autosave"
behavior — saving the parent automatically saves any new, not-yet-saved
child records in the same database transaction. If the user fails
validation (e.g. passwords don't match), `@organization.save` returns
`false` too — nothing gets half-created. This isn't something I assumed;
`test/controllers/registrations_controller_test.rb` proves it with a real
request and a duplicate-name / mismatched-password case.

### `Organization`, `User`, `Document` — how they relate

```ruby
# app/models/organization.rb
has_many :users, dependent: :restrict_with_error
has_many :documents, dependent: :destroy

# app/models/user.rb
belongs_to :organization
has_many :documents, dependent: :nullify

# app/models/document.rb
belongs_to :organization
belongs_to :user, optional: true
```

`belongs_to`/`has_many` are how Rails models express foreign-key
relationships in Ruby instead of raw SQL joins. The `dependent:` option on
each answers "what happens to the children when the parent is deleted" —
and each one here is a deliberate choice, not a default:
- Deleting an `Organization` with users **fails with an error**
  (`restrict_with_error`) — a safety rail against accidentally wiping a
  whole company's account.
- Deleting an `Organization` **does** delete its `Document`s
  (`destroy`) — a document is meaningless without the org it belongs to.
- Deleting a `User` **doesn't** delete their `Document`s — it just clears
  the `user_id` (`nullify`, and `belongs_to :user, optional: true` on
  `Document` makes that column nullable). The reasoning: the uploader is
  audit metadata ("who added this"), not the actual owner of the
  knowledge — an employee leaving shouldn't erase institutional knowledge.

### Routing: `resource` vs `resources`

```ruby
resource :session          # singular — no ID in the URL
resource :registration, only: %i[ new create ]
resources :passwords, param: :token   # plural — identified by a token
```
`resources :passwords` generates ID-based routes (`/passwords/:token/edit`)
because a password reset request is a specific, identifiable thing.
`resource :session` (no `s`) generates routes with no ID
(`/session`, not `/session/5`) because there's no "which session" from
the browser's point of view — you either have one or you don't.

### The database-isolation bug (worth understanding, not just fixing)

`.env` sets one `DATABASE_URL`. `dotenv-rails` loads `.env` in *every*
environment unless a more specific file exists. Result: running tests
was silently pointed at the **development** database, not a separate test
one — test runs were truncating and reloading fixtures into real dev
data. The fix, `.env.test`, works because dotenv-rails checks for an
environment-specific file first and prefers it over the generic `.env`.
Lesson: when a `.env`-style file is shared across environments by
default, that's a footgun waiting to happen — environments should be
isolated by default, not by remembering to configure it.

### Tailwind CSS — how "styled HTML" actually gets to the browser

Tailwind isn't hand-written CSS — you write utility class names directly
in HTML (`class="rounded-md bg-gray-900 px-3 py-2"`), and a build step
scans your `.erb` files for every class name actually used, then compiles
*only those* into one CSS file (`app/assets/builds/tailwind.css` —
gitignored, rebuilt on every deploy). The layout links it via
`stylesheet_link_tag "tailwind"`. This bit me directly: I once overwrote
the whole layout file and accidentally deleted that link tag — the page
still had all the right class names in its HTML, but no CSS file loading
them, so it rendered completely unstyled. Class names alone do nothing;
the compiled, *linked* stylesheet is what turns them into actual style.

---

## Concepts worth a YouTube video before Phase 3

Phase 3 (document upload → chunking → embeddings → vector search) will
introduce: Active Storage (file uploads), background jobs (Solid Queue),
what an embedding actually is, and cosine similarity. Good subjects to
look up before we get there — see the recap message from earlier in this
project for search terms.
