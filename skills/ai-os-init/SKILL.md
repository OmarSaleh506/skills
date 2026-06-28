---
name: ai-os-init
description: >-
  Scaffolds an "AI Operating System" project structure into any project,
  non-destructively — adds only missing pieces, never removes or overwrites
  anything that already exists. Creates: CLAUDE.md (memory layer),
  docs/architecture.md + docs/decisions/ + docs/runbooks/ (documentation),
  tools/scripts/ and tools/prompts/ (utilities), and .claude/ with two example
  skills (new-adr, clean-tests), six hooks (guard-secrets, branch-guard,
  auto-format, typecheck, n+1-guard, audit-log), and a read-only docs-auditor
  subagent — all wired via .claude/settings.json. Requires only Python 3 and
  bash; no external dependencies. Use when asked to "init Claude Code project
  structure", "scaffold the AI-OS layers", "add CLAUDE.md hooks subagents to
  this project", "set up the Claude Code layers", "initialize ai-os", "add the
  AI operating system structure", "scaffold this project for Claude Code", or
  "add skills hooks agents here". Safe to re-run — idempotent.
---

# ai-os-init

Scaffolds the five-layer AI Operating System structure into any project
directory. **Non-destructive by design**: existing files are never touched,
hook entries are never duplicated, source trees are never imposed.

**No dependencies** — needs only Python 3 and bash, both already present on any
machine running Claude Code. The hooks that call formatters or type checkers
(ruff, prettier, tsc, mypy, …) degrade silently when those tools aren't
installed, so nothing ever breaks.

## The Five Layers It Wires Up

| # | Layer | What gets created |
|---|---|---|
| 01 | **Memory** | `CLAUDE.md` — always-loaded project map, conventions, links |
| 02 | **Knowledge** | `.claude/skills/new-adr/` + `.claude/skills/clean-tests/` — on-demand skills |
| 03 | **Guardrails** | `.claude/hooks/` — six PreToolUse/PostToolUse hooks (see below) |
| 04 | **Delegation** | `.claude/agents/docs-auditor.md` — read-only docs drift subagent |
| 05 | **Docs** | `docs/` architecture + decisions (ADR log) + runbooks |

### Hooks installed (wired into `.claude/settings.json`)

| Hook | Event | What it does |
|---|---|---|
| `guard-secrets.sh` | PreToolUse (Edit/Write) | **Blocks** writes to secret-looking files (.env, keys, credentials) |
| `branch-guard.sh` | PreToolUse (Bash) | **Blocks** force-push and direct commit/push to protected branches; runs CI before push |
| `auto-format.sh` | PostToolUse (Edit/Write) | Formats the edited file (ruff/black/prettier/gofmt/rustfmt), best-effort |
| `typecheck.sh` | PostToolUse (Edit/Write) | Surfaces type errors (tsc/mypy) if the project is configured for them |
| `n+1-guard.sh` | PostToolUse (Edit/Write) | Warns on likely N+1 query patterns (DB call inside a loop) |
| `audit-log.sh` | PostToolUse (Bash) | Silently appends every bash command to `.claude/command-audit.log` |

> Two of these change git/agent behaviour out of the box: **`branch-guard.sh`**
> will block commits on `main/master/develop/staging/production` and force
> pushes, and **`audit-log.sh`** logs every command. Tell your team these are
> active, or drop the hooks you don't want from `templates/.claude/hooks/`
> before sharing.

## How to Run

Tell Claude to run the scaffold on the current project:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/ai-os-init/scaffold.py"
# or for a specific path:
python3 "${CLAUDE_PLUGIN_ROOT}/skills/ai-os-init/scaffold.py" /path/to/project
```

Report the created/skipped/merged summary to the user.

## Non-Destructive Contract

- **File exists →** skip it, report it as "already present"
- **File missing →** create it from the template
- **`.claude/settings.json` →** load and merge; append each hook entry **only
  if** a hook with the same command isn't already there — then write back
  preserving all existing keys
- **`CLAUDE.md` exists →** leave it byte-identical; note which recommended
  sections are absent so the user can fill them in
- **No `src/` imposed** — if the project has `src/`, `lib/`, or `app/` but
  no nested `CLAUDE.md`, suggest adding one; never create source dirs

## What to Do After Scaffolding

After running, guide the user through:
1. Fill in `CLAUDE.md` — project name, conventions, key commands
2. Fill in `docs/architecture.md` — tech stack, components, data flow
3. Try `new-adr`: say "create an ADR about [decision]"
4. Try `clean-tests`: say "clean up the tests"
5. Try `docs-auditor`: say "audit the docs"
6. `guard-secrets` is already active — it blocks writes to secret-looking files

## Template Source

All templates live alongside this skill in `templates/`. To customise what gets
created in future projects, fork the repo and edit the templates there (editing
the installed plugin cache directly gets overwritten on the next update).
