# [Project Name]

_One-sentence description._

## Quick Start

```bash
# Add setup / run commands here
```

## Structure

```
.
├── CLAUDE.md              # AI context & project map (memory layer)
├── docs/
│   ├── architecture.md    # System design and tech stack
│   ├── decisions/         # Architecture Decision Records (ADRs)
│   └── runbooks/          # Operational procedures
├── tools/
│   ├── scripts/           # Utility scripts
│   └── prompts/           # Reusable Claude prompts
└── .claude/               # AI-OS configuration
    ├── skills/            # new-adr (numbered ADRs), clean-tests (test refactor)
    ├── hooks/             # guard-secrets, branch-guard, auto-format, typecheck, n+1-guard, audit-log
    └── agents/            # Docs-auditor subagent
```

## AI-OS

This project uses Claude Code's AI Operating System pattern. See
[CLAUDE.md](CLAUDE.md) for project context. The scaffold was created by the
`ai-os-init` skill — safe to re-run at any time (idempotent, non-destructive):
ask Claude to **"run the ai-os-init skill"**.
