# Changelog

All notable changes to the `omar-skills` plugin. Versions match
`.claude-plugin/plugin.json`.

## 1.5.0 — 2026-10-07

### sqlalchemy-patterns
- Verified against SQLAlchemy 2.1 and Alembic 1.20 docs; every change cites its source.
- Split the 918-line SKILL.md into a 215-line core (cheatsheet, decision guide,
  pre-query checklist, common mistakes) plus 8 on-demand `references/` files.
- Fixed: timezone-aware `datetime` mapping, async-safe `onupdate` read-back,
  explicit cascades instead of `all`, documented event targets, a test fixture
  that leaked data on `commit()`.
- Added: 2.1 upgrade notes, `WriteOnlyMapped`, bulk `INSERT … RETURNING` and
  upserts, asyncpg behind PgBouncer, Alembic async `env.py` and `alembic check`.

### ai-os-init
- Hooks aligned with the current Claude Code hooks spec: block reasons now go to
  stderr and warnings use `additionalContext`, so Claude actually sees them.
- Hook commands use `$CLAUDE_PROJECT_DIR`, so they survive a `cd`.
- `branch-guard` rewritten: allows `--force-with-lease`, catches `push -f`,
  `+ref` and bare pushes on protected branches; no false hits on `feature/main-fix`.
- `guard-secrets` no longer blocks `.env.example` and friends; now catches
  `secrets.yaml`, `client_secret.json`, `.kube/config`, `.netrc`.
- `n+1-guard` JS/TS detection fixed; invalid `LS` tool removed from docs-auditor.
- `scaffold.py`: `--dry-run`, safer symlink handling, merges into existing
  `settings.json` without duplicates.

### shop-scout
- Firecrawl v2 scrape forces fresh prices (`maxAge: 0`), retries 429/5xx with
  backoff, clear errors for 401/402/429/unreachable, `--help`.
- New `references/buying-notes.md`: cross-border VAT/duty/currency and a
  "is this discount real?" check.
- Store and coupon lists cleaned (defunct sites removed, Xcite region fixed).

### system-flow-mapper
- Mermaid 10.9.3 → 12.1.0 (vendored, unmodified, sha256-pinned in
  `assets/MERMAID_VERSION.txt`), with a provenance section in SKILL.md.
- Playbooks updated: FastAPI `lifespan`, Next.js 16 `proxy` convention, Flux
  stable API versions.

### Repo
- CI `validate` workflow: manifests agree, frontmatter valid, README row per
  skill, SKILL.md ≤ 500 lines, bundled Python/shell compile.
- `.gitleaks.toml` allowlists the vendored Mermaid bundle (minified identifiers
  tripped `generic-api-key`).

## 1.4.0
- shop-scout added; README rewritten for discoverability.
