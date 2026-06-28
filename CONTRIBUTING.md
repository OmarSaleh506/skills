# Contributing

This is a **public** repository. Anything merged here is visible to the world,
forever (git history outlives deletion). The single most important rule:

> **Audit every skill before adding it. Never commit a skill that contains
> secrets, credentials, or machine-/work-specific details.**

## Pre-add checklist

Before adding or updating a skill, verify:

- [ ] **No secrets** — no API keys, tokens, passwords, connection strings, or
      `.env` contents anywhere (including example snippets).
- [ ] **No personal/work identifiers** — no internal hostnames, cluster names,
      tenant/account IDs, real emails, employer-specific service names, or
      private URLs.
- [ ] **No machine-specific absolute paths** — use `${CLAUDE_PLUGIN_ROOT}`,
      `~`, or relative paths. Never hardcode `/Users/<you>/...`.
- [ ] **No external dependency assumptions** — if the skill needs a tool that
      isn't Python 3 / bash, it must degrade gracefully (skip, don't fail) and
      say so in the SKILL.md.
- [ ] **Generic, not internal** — the skill solves a problem anyone could have,
      not one specific to a particular company's infrastructure. Infra-specific
      tooling belongs in a private repo, not here.

A quick local scan helps:

```bash
grep -rniE "api[_-]?key|secret|token|password|/Users/|@.*\.(com|io|sa)" skills/
```

CI also runs [gitleaks](https://github.com/gitleaks/gitleaks) on every push and
pull request as a backstop — but it is not a substitute for the manual review
above.

## Adding a skill

1. Drop it under `skills/<skill-name>/` (must contain `SKILL.md`).
2. Decide its invocation kind (see [CLAUDE.md](CLAUDE.md)): **model-invoked**
   (default — rich trigger description) or **user-invoked**
   (`disable-model-invocation: true` — concise, human-facing description).
3. Add `"./skills/<skill-name>"` to the `skills` arrays in **both**
   `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (they must
   always agree).
4. Add a row to the table in `README.md`, linking the skill name to its
   `SKILL.md`.
5. Bump the `version` in `plugin.json`.

## Releasing

Tag a release with the bundled CLI, which checks `plugin.json` and the
marketplace entry agree:

```bash
claude plugin tag .
```
