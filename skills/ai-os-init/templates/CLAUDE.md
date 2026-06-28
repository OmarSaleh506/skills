# [Project Name]

> _One-sentence description of what this project does._

## Project Map

| Layer | Path | Purpose |
|---|---|---|
| Source | `src/` (or `lib/`, `app/`) | Application code |
| Docs | `docs/` | Architecture, decisions, runbooks |
| Tools | `tools/` | Scripts and reusable prompts |
| AI Config | `.claude/` | Skills, hooks, subagents |

_Tip: edit the table above to match your actual layout._

## Conventions

_Fill these in so Claude always follows project standards without being reminded:_

- **Language / framework:** _e.g. Python 3.12, FastAPI_
- **Testing:** _e.g. pytest — run `make test`_
- **Linting / formatting:** _e.g. ruff, black — run `make lint`_
- **Commit style:** _e.g. conventional commits: `feat:`, `fix:`, `docs:`_
- **Branch naming:** _e.g. `feature/`, `fix/`, `chore/`_

## Key Commands

```bash
# Add the commands you run every day
# e.g.:
# make dev      — start dev server
# make test     — run full test suite
# make lint     — check code style
# make deploy   — ship to production
```

## Docs

- [Architecture](docs/architecture.md) — system design and tech stack
- [Decisions](docs/decisions/) — Architecture Decision Record (ADR) log
- [Runbooks](docs/runbooks/) — operational procedures

## AI-OS Layers Active in This Project

| Layer | What's configured |
|---|---|
| 📋 Memory | This file |
| 📚 Skills | `.claude/skills/new-adr/` (numbered ADRs), `.claude/skills/clean-tests/` (test refactor) |
| 🛡️ Hooks | `.claude/hooks/` — guard-secrets, branch-guard, auto-format, typecheck, n+1-guard, audit-log |
| 🤖 Subagents | `.claude/agents/docs-auditor.md` — audits docs for drift |

> `branch-guard` blocks commits/pushes on protected branches and force-pushes;
> `audit-log` records every bash command to `.claude/command-audit.log`. Remove
> any hook you don't want from `.claude/hooks/` and its entry in `settings.json`.
