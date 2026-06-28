#!/usr/bin/env python3
"""
ai-os-init scaffold — idempotent, non-destructive project initializer.

Usage:
    python3 <path-to>/scaffold.py [target_dir]

    target_dir defaults to the current working directory.
    When installed as a Claude Code plugin, this lives at
    ${CLAUDE_PLUGIN_ROOT}/skills/ai-os-init/scaffold.py

Safe to re-run at any time:
  - Existing files are NEVER modified or overwritten.
  - Hook entries are NEVER duplicated in settings.json (deduped by command string).
  - Source trees (src/, lib/, app/) are NEVER created if absent.

Requires only Python 3 and bash — no external dependencies.
"""

import os
import sys
import json
import shutil
import stat

# ──────────────────────────────────────────────────────────────────────────────
# Paths
# ──────────────────────────────────────────────────────────────────────────────

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SKILL_DIR, "templates")

# ──────────────────────────────────────────────────────────────────────────────
# Standard hooks merged into .claude/settings.json
# All are idempotent — deduped by command string, never duplicated on re-run.
# ──────────────────────────────────────────────────────────────────────────────

def _h(command):
    return {"type": "command", "command": command}


STANDARD_HOOKS = {
    "PreToolUse": [
        # Security: block writes to secret-looking files
        {"matcher": "Edit|Write|MultiEdit", "hooks": [_h("bash .claude/hooks/guard-secrets.sh")]},
        # Safety: block direct commits/pushes to main/master and force pushes
        {"matcher": "Bash",                 "hooks": [_h("bash .claude/hooks/branch-guard.sh")]},
    ],
    "PostToolUse": [
        # Quality: auto-format every file after edit (ruff/black/prettier/gofmt/rustfmt)
        {"matcher": "Edit|Write|MultiEdit", "hooks": [_h("bash .claude/hooks/auto-format.sh")]},
        # Quality: run type checker on modified file if project has one configured
        {"matcher": "Edit|Write|MultiEdit", "hooks": [_h("bash .claude/hooks/typecheck.sh")]},
        # Performance: warn on N+1 query patterns (DB call inside a for loop)
        {"matcher": "Edit|Write|MultiEdit", "hooks": [_h("bash .claude/hooks/n+1-guard.sh")]},
        # Audit: silent append of every bash command to .claude/command-audit.log
        {"matcher": "Bash",                 "hooks": [_h("bash .claude/hooks/audit-log.sh")]},
    ],
}


def _hook_commands(entry):
    """Extract all command strings from a hook entry (for dedup check)."""
    return {h.get("command", "") for h in entry.get("hooks", [])}


def _is_hook_present(existing_entries, new_entry):
    """Return True if any existing entry already uses the same command(s)."""
    new_cmds = _hook_commands(new_entry)
    return any(_hook_commands(e) & new_cmds for e in existing_entries)


# ──────────────────────────────────────────────────────────────────────────────
# Settings.json merge
# ──────────────────────────────────────────────────────────────────────────────

def merge_settings_json(root, created, skipped, merged):
    """
    Merge all STANDARD_HOOKS into <root>/.claude/settings.json.
    Preserves every existing key. Never duplicates any hook entry.
    """
    claude_dir = os.path.join(root, ".claude")
    settings_path = os.path.join(claude_dir, "settings.json")

    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as fh:
                settings = json.load(fh)
        except (json.JSONDecodeError, OSError) as exc:
            _warn(f".claude/settings.json exists but couldn't be parsed: {exc}")
            _warn("Skipping hook merge to avoid data loss.")
            skipped.append(".claude/settings.json  ← parse error, skipped")
            return
    else:
        settings = {}
        os.makedirs(claude_dir, exist_ok=True)

    hooks_block = settings.setdefault("hooks", {})
    added = []

    for event_type, hook_entries in STANDARD_HOOKS.items():
        event_list = hooks_block.setdefault(event_type, [])
        for entry in hook_entries:
            cmd = list(_hook_commands(entry))[0]
            if _is_hook_present(event_list, entry):
                skipped.append(f".claude/settings.json  ← already present: {cmd}")
            else:
                event_list.append(entry)
                added.append(cmd)

    if not added:
        return

    try:
        with open(settings_path, "w", encoding="utf-8") as fh:
            json.dump(settings, fh, indent=2)
            fh.write("\n")
        for cmd in added:
            merged.append(f".claude/settings.json  ← added hook: {cmd}")
    except OSError as exc:
        _warn(f"Could not write .claude/settings.json: {exc}")


# ──────────────────────────────────────────────────────────────────────────────
# CLAUDE.md section check
# ──────────────────────────────────────────────────────────────────────────────

RECOMMENDED_SECTIONS = [
    "## Project Map",
    "## Conventions",
    "## Key Commands",
    "## Docs",
]


def check_claude_md(root):
    """
    If CLAUDE.md exists, report which recommended sections are absent.
    Returns a list of missing section headers (empty = all present).
    """
    path = os.path.join(root, "CLAUDE.md")
    if not os.path.exists(path):
        return []  # file missing — scaffold will create it
    try:
        content = open(path, encoding="utf-8").read()
    except OSError:
        return []
    return [s for s in RECOMMENDED_SECTIONS if s not in content]


# ──────────────────────────────────────────────────────────────────────────────
# Source-dir check
# ──────────────────────────────────────────────────────────────────────────────

SOURCE_DIR_CANDIDATES = ["src", "lib", "app"]


def bare_source_dirs(root):
    """
    Return source dirs that exist but have no nested CLAUDE.md.
    We never create these — only suggest adding CLAUDE.md to them.
    """
    result = []
    for d in SOURCE_DIR_CANDIDATES:
        full = os.path.join(root, d)
        if os.path.isdir(full) and not os.path.exists(os.path.join(full, "CLAUDE.md")):
            result.append(d)
    return result


# ──────────────────────────────────────────────────────────────────────────────
# Output helpers
# ──────────────────────────────────────────────────────────────────────────────

def _warn(msg):
    print(f"  ⚠️  {msg}", file=sys.stderr)


def _print_list(icon, header, items):
    if not items:
        return
    print(f"\n{icon} {header}:")
    for item in items:
        print(f"   {item}")


# ──────────────────────────────────────────────────────────────────────────────
# Main scaffold
# ──────────────────────────────────────────────────────────────────────────────

def scaffold(target=None):
    root = os.path.abspath(target or os.getcwd())

    print(f"\n🏗️  ai-os-init scaffold")
    print(f"   Target : {root}")
    print(f"   Mode   : non-destructive (existing files are never modified)\n")

    created = []
    skipped = []
    merged = []

    # ── Step 1: Copy all templates (skip existing) ───────────────────────────
    for src_root_str, dirs, files in os.walk(TEMPLATES_DIR):
        # sort dirs for deterministic output
        dirs.sort()

        rel_dir = os.path.relpath(src_root_str, TEMPLATES_DIR)

        for filename in sorted(files):
            src_file = os.path.join(src_root_str, filename)

            if rel_dir == ".":
                rel_dest = filename
            else:
                rel_dest = os.path.join(rel_dir, filename)

            dst_file = os.path.join(root, rel_dest)

            if os.path.exists(dst_file):
                skipped.append(rel_dest)
                continue

            os.makedirs(os.path.dirname(dst_file), exist_ok=True)
            shutil.copy2(src_file, dst_file)

            # Shell scripts need the executable bit
            if filename.endswith(".sh"):
                mode = os.stat(dst_file).st_mode
                os.chmod(dst_file, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

            created.append(rel_dest)

    # ── Step 2: Merge hooks into .claude/settings.json ────────────────────────
    merge_settings_json(root, created, skipped, merged)

    # ── Step 3: Check existing CLAUDE.md for missing sections ─────────────────
    missing_sections = check_claude_md(root)

    # ── Step 4: Note bare source dirs ─────────────────────────────────────────
    bare = bare_source_dirs(root)

    # ── Report ────────────────────────────────────────────────────────────────
    _print_list("✅", "Created", [f"+ {f}" for f in created])
    _print_list("🔀", "Merged", [f"~ {f}" for f in merged])
    _print_list("⏭️ ", "Skipped (already present)", [f"= {f}" for f in skipped])

    if missing_sections:
        print(f"\n💡 Your CLAUDE.md exists but is missing recommended sections:")
        for s in missing_sections:
            print(f"   {s}")
        print(f"   Consider adding them (see templates/CLAUDE.md for reference).")

    if bare:
        print(f"\n💡 Source dir(s) exist without a nested CLAUDE.md:")
        for d in bare:
            print(f"   {d}/CLAUDE.md — add sub-module context for better AI navigation")

    total = len(created) + len(merged)
    if total > 0:
        print(f"\n✨ Done: {len(created)} created, {len(merged)} merged, {len(skipped)} skipped.")
        print(f"\n📋 Next steps:")
        print(f"   1. Edit CLAUDE.md  — fill in project name, conventions, key commands")
        print(f"   2. Edit docs/architecture.md — describe your system's tech stack")
        print(f"   3. Try the new-adr skill: tell Claude 'create an ADR about [decision]'")
        print(f"   4. Try docs-auditor: tell Claude 'audit the docs'")
        print(f"   5. guard-secrets is active — blocks writes to secret-looking files")
    else:
        print(f"\n🟰 Already up to date: 0 created, 0 merged, {len(skipped)} skipped.")
        print(f"   Nothing to do — this project already has the full AI-OS structure.")


# ──────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    target_arg = sys.argv[1] if len(sys.argv) > 1 else None
    scaffold(target_arg)
