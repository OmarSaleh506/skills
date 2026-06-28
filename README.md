# skills

A collection of portable agent skills. Each skill is a self-contained
`SKILL.md` (plus any supporting scripts) — plain markdown instructions an AI
coding agent follows. They're packaged here as a
[Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace
for one-command install, but the skill files are portable and can be used by
any agent that reads skill/instruction files.

## Install (Claude Code)

```text
/plugin marketplace add OmarSaleh506/skills
/plugin install omar-skills@skills
```

One install gives you every skill in this collection. Each model-invoked skill
then activates automatically when what you ask Claude to do matches its
description.

## Use with other agents

Each skill lives under `skills/<name>/`. Copy that folder into your agent's
skills/instructions directory, or just point your agent at the `SKILL.md`.
No install step required — they're plain files.

## Skills in this collection

| Skill | Invocation | What it does |
|---|---|---|
| **[ai-os-init](./skills/ai-os-init/SKILL.md)** | model-invoked | Non-destructively scaffolds the five-layer "AI Operating System" structure into any project: `CLAUDE.md` (memory), `docs/` (architecture + ADR log + runbooks), `tools/`, and `.claude/` with example skills, hooks, and a docs-auditor subagent. Idempotent and safe to re-run. |

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
