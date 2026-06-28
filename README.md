# skills

A collection of portable agent skills. Each skill is a self-contained
`SKILL.md` (plus any supporting scripts) — plain markdown instructions an AI
coding agent follows. They're packaged here as a
[Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace
for one-command install, but the skill files are portable and can be used by
any agent that reads skill/instruction files.

## Install

**Any agent** (Claude Code, Codex, Cursor, OpenCode + 70 more) — via the
[`skills`](https://skills.sh) installer:

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

Model-invoked skills then activate automatically when your request matches their
description.

## Skills in this collection

| Skill | Works in | What it does |
|---|---|---|
| **[ai-os-init](./skills/ai-os-init/SKILL.md)** | Claude Code | Non-destructively scaffolds the five-layer "AI Operating System" structure into any project: `CLAUDE.md` (memory), `docs/` (architecture + ADR log + runbooks), `tools/`, and `.claude/` with example skills, hooks, and a docs-auditor subagent. (Sets up Claude Code's `.claude/` config, so it's Claude-specific.) |
| **[sqlalchemy-patterns](./skills/sqlalchemy-patterns/SKILL.md)** | Any agent | The definitive SQLAlchemy 2.0+ reference (async · PostgreSQL): 2.0-style declarative models, relationships, eager-loading strategy, N+1 elimination, transactions, PostgreSQL types, and Alembic — with a 30-second cheatsheet, pre-query checklist, and troubleshooting table. |
| **[system-flow-mapper](./skills/system-flow-mapper/SKILL.md)** | Any agent | Reads any codebase (no changes) and writes three deliverables to `docs/system-flow/`: a deep `SYSTEM_FLOW.md` technical map, a jargon-free offline HTML companion for non-technical readers, and an interactive offline HTML reference for engineers. Detects project type (backend, frontend, full-stack, Pulumi, Flux/GitOps, IaC). |

### ai-os-init — what gets installed into your project

Running it scaffolds only the pieces you're missing — existing files are never
touched:

- `CLAUDE.md` — always-loaded project map and conventions
- `docs/architecture.md`, `docs/decisions/` (ADR log), `docs/runbooks/`
- `tools/scripts/`, `tools/prompts/`
- `.claude/skills/` — `new-adr` (numbered ADRs) and `clean-tests` (test refactor)
- `.claude/agents/docs-auditor.md` — read-only docs-drift auditor
- `.claude/hooks/` — six hooks wired into `.claude/settings.json`:
  `guard-secrets`, `branch-guard`, `auto-format`, `typecheck`, `n+1-guard`, `audit-log`

> **Heads-up — two hooks change behavior out of the box.** `branch-guard`
> blocks force-pushes and direct commits/pushes to protected branches
> (`main`/`master`/`develop`/`staging`/`production`), and `audit-log` records
> every bash command to `.claude/command-audit.log`. Both are opinionated by
> design. Delete any hook you don't want from `.claude/hooks/` and remove its
> entry from `.claude/settings.json` after scaffolding.

**No dependencies** — needs only Python 3 and bash. The formatter/type-check
hooks self-skip when the underlying tool (ruff, prettier, tsc, mypy, …) isn't
installed, so nothing breaks.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Because this repo is **public**, every
skill is audited for secrets, credentials, and machine-/work-specific details
before it's added.

## License

[MIT](LICENSE)
