# Repo conventions

This is a **public** Claude Code plugin marketplace of portable agent skills.
The whole collection ships as one plugin, `omar-skills`, in the `skills`
marketplace.

## Layout

```
.claude-plugin/
  marketplace.json   # the marketplace ("skills") + the omar-skills plugin entry
  plugin.json        # the omar-skills plugin manifest
skills/
  <skill-name>/
    SKILL.md         # required — the skill itself
    ...              # optional supporting scripts / reference docs
```

## Rules for every shipped skill

- It lives at `skills/<name>/SKILL.md`.
- It is listed in the `skills` array of **both** `.claude-plugin/plugin.json`
  **and** `.claude-plugin/marketplace.json` (the two must always agree).
- It has a row in `README.md`, with the skill name linked to its `SKILL.md`.
- Bump `version` in `plugin.json` when you change what ships.

## Invocation: model-invoked vs user-invoked

Every skill is one of two kinds, set in its `SKILL.md` frontmatter:

- **model-invoked** (default) — reachable by the model *or* the user. Keep a
  rich, trigger-heavy `description` ("Use when the user wants…, asks for…") so
  it auto-fires. Use this for reusable discipline. `ai-os-init` is model-invoked.
- **user-invoked** — reachable only when the human types its name. Set
  `disable-model-invocation: true`; keep the `description` short and
  human-facing. Use this for orchestration skills you want to fire deliberately.

A user-invoked skill may invoke model-invoked skills, never another
user-invoked one.

## Before adding anything

This repo is **public** — anything merged is visible forever (git history
outlives deletion). Audit every skill before adding it; never commit one that
contains secrets or machine-/work-specific details. Verify:

- **No secrets** — no API keys, tokens, passwords, connection strings, or `.env`
  contents anywhere (including example snippets).
- **No personal/work identifiers** — no internal hostnames, cluster/tenant names,
  account IDs, real emails, employer-specific service names, or private URLs.
- **No machine-specific absolute paths** — use `${CLAUDE_PLUGIN_ROOT}`, `~`, or
  relative paths. Never hardcode `/Users/<you>/...`.
- **Degrades gracefully** — if a skill needs a tool beyond Python 3 / bash, it
  must skip rather than fail, and say so in its `SKILL.md`.
- **Generic, not internal** — solves a problem anyone could have; infra- or
  employer-specific tooling belongs in a private repo, not here.

A quick local scan before committing:

```bash
grep -rniE "api[_-]?key|secret|token|password|/Users/|@.*\.(com|io|sa)" skills/
```

CI also runs gitleaks on every push/PR as a backstop — not a substitute for the
review above.

## Paths inside a skill

When a skill shells out to its own bundled script, reference it by a
**skill-relative variable** (e.g. `$SKILL_DIR`, the folder the skill's `SKILL.md`
lives in) — never a hardcoded `~/.claude/...` or `/Users/...` path. Resolve that
variable per install: `${CLAUDE_PLUGIN_ROOT}/skills/<name>` for a Claude Code
plugin install, or the skill's own directory for `npx skills` / manual / other
agents. This keeps skills runnable on any agent, not only Claude Code.

A skill's **output** should go to the OS temp dir or into the analyzed project —
never `~/.claude/...` (it confuses non-Claude users).
