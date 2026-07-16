# 5. Rebuild Ruby natively for arm64

## Status
Accepted

## Context
This Mac was set up via Migration Assistant from an old Intel Mac. Ruby
(via rvm), Homebrew (`/usr/local`), and every native gem extension were
x86_64 binaries, running under Rosetta 2 translation for the entire
project up to this point — invisible because almost everything tolerates
Rosetta fine (slower, but correct). It surfaced only when
`tailwindcss-ruby`'s bundled CLI (built on Bun, which is sensitive to
missing AVX instructions under translation) started crashing its watch
mode, killing the whole `bin/dev` process group.

Fixing Tailwind specifically would have meant re-hitting this same class
of bug on the next AVX-sensitive or arch-sensitive native gem later.

## Decision
Rebuilt Ruby 3.3.4 as a genuine native arm64 binary:
1. Recompiled Ruby from source (`rvm install 3.3.4 --disable-binary` after
   `rvm uninstall 3.3.4`) — RVM had no arm64 binary available for this
   macOS version, so source compilation was required either way.
2. The `openssl@1.1` in the existing x86_64 Homebrew is too old/opaque an
   API for Ruby 3.3's `openssl_missing.c` to compile against regardless of
   target architecture — this bug wasn't new, it just was never hit
   because the original x86_64 Ruby had been copied over pre-built during
   machine migration, never compiled locally at all.
3. Installing a *second*, native arm64 Homebrew at the standard
   `/opt/homebrew` path (the normal way both architectures coexist on
   Apple Silicon) needs `sudo`, and this account has no admin rights.
   Installed one into a user-owned custom prefix (`~/.homebrew-arm64`)
   instead — works for fetching precompiled bottles for some formulae
   (`readline`, `gmp`, `libyaml`), but Homebrew's own bottles are built
   assuming the standard prefix and fall back to source builds otherwise,
   which then hit a Homebrew-imposed Xcode Command Line Tools version gate
   this account also can't clear without an OS-level update.
4. Worked around the CLT gate entirely for OpenSSL specifically by
   building it directly from openssl.org's source tarball with our
   existing (working) native `clang` — bypassing Homebrew's formula
   policy check, which turned out to be a Homebrew safety policy, not an
   actual compiler incompatibility.
5. Ruby's top-level `./configure` step had baked stale x86_64 `-L` paths
   into `RbConfig::CONFIG['LDFLAGS']` from an earlier attempt, silently
   breaking the `zlib` and `psych` extensions too (not just `openssl`).
   Rebuilt each by hand with explicit `--with-*-dir`/`PKG_CONFIG_LIBDIR`
   overrides, since a stray system-default `pkg-config` search path
   (`/usr/local/lib/pkgconfig`) kept resolving back to the wrong-arch
   libraries even with correct-looking flags.
6. Recreated the `rag-mvp` rvm gemset from scratch and reinstalled all
   gems — `bundle install` correctly picked native arm64 builds
   (`tailwindcss-ruby`, `pg`, `nokogiri`, etc.) once the underlying Ruby
   itself was genuinely arm64.

## Why
- The AVX crash was a symptom, not the actual problem — the actual
  problem was every native extension in the project silently running
  translated, with worse performance and a growing chance of hitting
  another architecture-sensitive tool later (exactly what happened here).
- Once identified, patching around it repeatedly (per-gem workarounds)
  costs more compounding time than fixing it once at the root.

## Tradeoffs accepted
- This machine now has three partial toolchains: the original x86_64
  Homebrew at `/usr/local` (still used for `gh`, Docker Desktop's CLI
  glue, etc. — untouched, still works), a mostly-unused custom-prefix arm64
  Homebrew at `~/.homebrew-arm64` (only `readline`/`gmp`/`libyaml` actually
  installed there), and a hand-built OpenSSL at `~/.local/openssl-arm64`.
  Messier than a clean single-Homebrew setup, but each piece is exactly
  what unblocked the next step and all are user-owned (no sudo residue).
- If this account gets admin rights later, the cleaner long-term fix is:
  install Homebrew properly at `/opt/homebrew`, update Xcode Command Line
  Tools, and let `brew install openssl@3 readline libyaml` just work with
  bottles — at that point `~/.homebrew-arm64` and `~/.local/openssl-arm64`
  can be deleted.
