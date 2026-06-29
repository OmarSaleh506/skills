# omar-skills

**Portable, install-once skills for AI coding agents.** Each skill is a single
`SKILL.md` of plain-markdown instructions your agent loads *automatically* the
moment your request matches — no prompt to paste, no copy-paste drift, the same
discipline every time, in every project.

Copy-pasted prompts rot: you tweak one, forget the rest, and every teammate ends
up running a slightly different version. A skill *is* the prompt — versioned,
shared, and installed once — so the agent reaches for it on its own, whether
that's Claude Code, Cursor, Codex, Gemini CLI, or Copilot.

[![License: MIT](https://img.shields.io/github/license/OmarSaleh506/skills)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-4-blue)](#skills)
[![Install via skills.sh](https://img.shields.io/badge/install-skills.sh-5b50e0)](https://skills.sh)
[![Last commit](https://img.shields.io/github/last-commit/OmarSaleh506/skills)](https://github.com/OmarSaleh506/skills/commits/main)

## Install

**Any agent** — via the [`skills`](https://skills.sh) installer (Claude Code,
Codex, Cursor, OpenCode + 70 more):

```bash
npx skills add OmarSaleh506/skills            # pick skills + agents interactively
npx skills add OmarSaleh506/skills -a codex   # e.g. install only to Codex
```

**Claude Code** — native plugin marketplace (one install pulls in every skill):

```text
/plugin marketplace add OmarSaleh506/skills
/plugin install omar-skills@skills
```

**Manual** — each skill is a self-contained folder under `skills/<name>/`; copy
it into your agent's skills directory, or point the agent at its `SKILL.md`.

> **Works with Claude Code, Cursor, Codex, Gemini CLI, and Copilot.**
> Model-invoked skills activate automatically when your request matches their
> description — you don't have to name them.

## Skills

| Skill | What it does | Use when | Works in |
|---|---|---|---|
| **[shop-scout](./skills/shop-scout/SKILL.md)** | Comparison-shops a product (or a whole list) across stores: ranks by **effective price** (after coupons + shipping), judges each seller **Trusted / Mixed / Risky**, and hunts working coupons. **Deterministic output**, and it degrades to an honest summary instead of a fake table when it can't read live prices. | You want the cheapest *and* safest place to buy something online. | Any agent |
| **[sqlalchemy-patterns](./skills/sqlalchemy-patterns/SKILL.md)** | The definitive **SQLAlchemy 2.0+** reference (async · PostgreSQL): 2.0-style models, eager-loading strategy, N+1 elimination, transactions, PostgreSQL types, and Alembic — with a 30-second cheatsheet and a pre-query checklist. | Writing any SQLAlchemy model, query, or migration. | Any agent |
| **[system-flow-mapper](./skills/system-flow-mapper/SKILL.md)** | Reads any codebase (source unchanged) and writes three deliverables to `docs/system-flow/`: a deep technical map, a jargon-free offline HTML companion for non-technical readers, and an interactive offline HTML reference for engineers. | Onboarding to — or documenting — a codebase's architecture and request flow. | Any agent |
| **[ai-os-init](./skills/ai-os-init/SKILL.md)** | Non-destructively scaffolds a five-layer "AI Operating System" into a project: `CLAUDE.md`, `docs/` (architecture + ADRs + runbooks), `tools/`, and a `.claude/` with example skills, hooks, and a docs-auditor agent. Idempotent. | Starting or standardizing a repo for a consistent Claude Code setup. | Claude Code |

## See it work — shop-scout

A **real** shop-scout run on self-hosted Firecrawl (prices as observed 2026-06-29).
Rows hold a fixed priority order, so two runs of the same query match. The winner is
the cheapest **in-stock** listing — the two cheaper rows are out of stock, so
shop-scout won't recommend them — and coupons it can't verify are labelled, never
silently folded into the price:

```text
### Logitech MX Master 3S — backend: self-host
| Store                 | Price      | Disc. | Effective  | Stock / Shipping      | Coupon          | Seller trust                            | Buy  |
|-----------------------|------------|-------|------------|-----------------------|-----------------|-----------------------------------------|------|
| Noon (eKart)          | SAR 449.00 | n/a   | SAR 449.00 | Low stock (5) · free  | none applicable | ✅ Trusted — eKart 4.8★/87% (listing)   | open |
| Amazon.sa (ALOTHAIBI) | SAR 499.00 | -8%   | SAR 499.00 | In stock · Amazon-FBA | none applicable | ⚠️ Mixed — 3rd-party, no rating (seller)| open |
| extra                 | SAR 299.00 | -47%  | SAR 299.00 | Out of stock          | none applicable | ✅ Trusted — eXtra 4.6★/1523 (listing)  | open |
| Jarir                 | SAR 379.00 | n/a   | SAR 379.00 | Out of stock          | none found      | ⚠️ Mixed — only a product rating read   | open |

Best buy (cheapest IN-STOCK): Noon — SAR 449.00.
extra (SAR 299) and Jarir (SAR 379) are cheaper but OUT OF STOCK, so they can't win;
Amazon.sa is in stock but pricier. Aggregator coupon codes were unverifiable, so none
were applied. (Run again and the same four rows come back in the same order.)
```

Without a scraping backend, shop-scout does **not** invent a table — it returns an
honest research summary (real links + any prices it could actually read) plus a
one-step guide to enabling Firecrawl. See the
[skill](./skills/shop-scout/SKILL.md) for the backend tiers.

> _Captured from a live self-host run; links and a few cells shortened for width.
> This is the locked output contract the skill produces — a recorded GIF/screencast
> is a planned nice-to-have._

## What `ai-os-init` scaffolds

Non-destructive (adds only what's missing) and safe to re-run:

```text
CLAUDE.md                    # always-loaded project map & conventions
docs/
  architecture.md
  decisions/                 # ADR log
  runbooks/
tools/
  scripts/   prompts/
.claude/
  skills/                    # new-adr, clean-tests
  agents/docs-auditor.md     # read-only docs-drift auditor
  hooks/                     # guard-secrets, branch-guard, auto-format,
                             #   typecheck, n+1-guard, audit-log
  settings.json              # wires the hooks
```

> **Two hooks are opinionated by design.** `branch-guard` blocks force-pushes and
> direct commits/pushes to protected branches (`main`/`master`/`develop`/
> `staging`/`production`); `audit-log` records every bash command. Delete any hook
> you don't want from `.claude/hooks/` and remove its entry from `settings.json`.
> No dependencies beyond Python 3 + bash — the formatter/type-check hooks self-skip
> when their tool (ruff, prettier, tsc, mypy, …) isn't installed.

## License

[MIT](LICENSE)
