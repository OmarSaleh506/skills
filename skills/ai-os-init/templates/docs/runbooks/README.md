# Runbooks

Step-by-step operational procedures for recurring tasks.
Add a new `.md` file here for each significant operation.

## Index

| Runbook | Trigger | Est. Time |
|---|---|---|
| _[Deployment](deploy.md)_ | _New release ready_ | _~5 min_ |
| _[Database migration](db-migrate.md)_ | _Schema change_ | _~10 min_ |
| _[Incident response](incident.md)_ | _Production alert_ | _variable_ |

_Replace this table with your project's actual runbooks._

---

## Runbook Format

Each runbook should answer five questions:

1. **When to use** — what situation triggers this runbook?
2. **Prerequisites** — what access, tools, or info is needed before starting?
3. **Steps** — numbered, actionable commands you can copy-paste directly
4. **Verify** — how to confirm it worked
5. **Rollback** — how to undo it if something went wrong

### Example skeleton

```markdown
# [Runbook Title]

**When to use:** [situation that triggers this]
**Prerequisites:** [access / env vars / tools needed]
**Estimated time:** [X minutes]

## Steps

1. `[command]` — [what it does]
2. `[command]` — [what it does]
3. [etc.]

## Verify

[How to confirm success, e.g. `curl` a health endpoint, check a dashboard]

## Rollback

[How to undo, e.g. `git revert`, restore from backup, redeploy previous version]
```
