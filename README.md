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

shop-scout with a real scraping backend (self-hosted Firecrawl), comparison-shopping
one product. Rows are in a fixed priority order; the winner is called out
separately, so the same query gives the same table every run:

```text
### Sony WH-1000XM5 — backend: self-host
| Store     | Price     | Discount | Effective price | Stock / Shipping     | Coupon                                   | Seller trust                                  | Buy link       |
|-----------|-----------|----------|-----------------|----------------------|------------------------------------------|-----------------------------------------------|----------------|
| Noon      | SAR 1,399 | -13%     | **SAR 1,399**   | In stock · free ship | none found                               | ✅ Trusted — major KSA marketplace (Trustpilot)| [open product] |
| Amazon.sa | SAR 1,420 | n/a      | **SAR 1,370**   | In stock · free ship | `SAVE50` · -SAR 50 · ✅ applicable · verify | ✅ Trusted — sold & shipped by Amazon.sa       | [open product] |
| Jarir     | SAR 1,449 | n/a      | **SAR 1,449**   | Low stock (3)        | none found                               | ✅ Trusted — established KSA chain (Trustpilot) | [open product] |

Best buy: Amazon.sa — SAR 1,370. Cheapest after the SAR 50 coupon, in stock, sold directly by Amazon.
```

Without a scraping backend, shop-scout does **not** invent a table — it returns an
honest research summary (real links + any prices it could actually read) plus a
one-step guide to enabling Firecrawl. See the
[skill](./skills/shop-scout/SKILL.md) for the backend tiers.

> _Illustrative sample output (links shortened for the README). The format above
> is the locked output contract the skill produces; a recorded GIF/screencast of
> a live run is a planned nice-to-have._

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
