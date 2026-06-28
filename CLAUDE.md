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

This repo is public. Follow the audit checklist in
[CONTRIBUTING.md](CONTRIBUTING.md) — no secrets, no machine-/work-specific
details, no hardcoded absolute paths. Infra- or employer-specific skills do not
belong here.

## Paths inside a skill

When a skill shells out to its own bundled script, reference it via
`${CLAUDE_PLUGIN_ROOT}` (resolves to the installed plugin location), never a
hardcoded `~/.claude/...` or `/Users/...` path.
