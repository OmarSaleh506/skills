#!/usr/bin/env python3
"""
ai-os-init scaffold — idempotent, non-destructive project initializer.

Usage:
    python3 <path-to>/scaffold.py [--dry-run] [target_dir]

    target_dir defaults to the current working directory.
    When installed as a Claude Code plugin, this lives at
    ${CLAUDE_PLUGIN_ROOT}/skills/ai-os-init/scaffold.py

Safe to re-run at any time:
  - Existing files are NEVER modified or overwritten.
  - Hook entries are NEVER duplicated in settings.json (deduped by hook script path).
  - Source trees (src/, lib/, app/) are NEVER created if absent.
  - --dry-run reports what would change and writes nothing.

Requires only Python 3 and bash — no external dependencies.
"""

import argparse
import json
import os
import shutil
import stat
import sys

# ──────────────────────────────────────────────────────────────────────────────
# Paths
# ──────────────────────────────────────────────────────────────────────────────

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SKILL_DIR, "templates")

# ──────────────────────────────────────────────────────────────────────────────
# Standard hooks merged into .claude/settings.json
# Deduped by hook script path, so re-runs (and upgrades) never duplicate them.
# ──────────────────────────────────────────────────────────────────────────────

SETTINGS_SCHEMA_URL = "https://json.schemastore.org/claude-code-settings.json"
HOOKS_REL_DIR = ".claude/hooks/"
EDIT_TOOLS = "Edit|Write|MultiEdit"


def _hook_entry(matcher, script):
    # Anchored to $CLAUDE_PROJECT_DIR so hooks still resolve after Claude `cd`s
    # into a subdirectory (a bare relative path breaks there).
    command = f'bash "${{CLAUDE_PROJECT_DIR}}/{HOOKS_REL_DIR}{script}"'
    return {"matcher": matcher, "hooks": [{"type": "command", "command": command}]}


STANDARD_HOOKS = {
    "PreToolUse": [
        _hook_entry(EDIT_TOOLS, "guard-secrets.sh"),
        _hook_entry("Bash", "branch-guard.sh"),
    ],
    "PostToolUse": [
        _hook_entry(EDIT_TOOLS, "auto-format.sh"),
        _hook_entry(EDIT_TOOLS, "typecheck.sh"),
        _hook_entry(EDIT_TOOLS, "n+1-guard.sh"),
        _hook_entry("Bash", "audit-log.sh"),
    ],
}


def _script_of(entry):
    command = entry["hooks"][0]["command"]
    return command.rsplit("/", 1)[-1].rstrip('"')


def _is_hook_present(existing_entries, script):
    """Match on the hook script path, not the exact command string, so entries
    written by older versions (`bash .claude/hooks/x.sh`) aren't duplicated."""
    needle = HOOKS_REL_DIR + script
    for entry in existing_entries:
        if not isinstance(entry, dict):
            continue
        for hook in entry.get("hooks") or []:
            if isinstance(hook, dict) and needle in str(hook.get("command", "")):
                return True
    return False


# ──────────────────────────────────────────────────────────────────────────────
# Settings.json merge
# ──────────────────────────────────────────────────────────────────────────────

def _load_settings(settings_path, skipped):
    """Return the parsed settings (a fresh dict if absent), or None if unusable."""
    if not os.path.exists(settings_path):
        return {"$schema": SETTINGS_SCHEMA_URL}
    try:
        with open(settings_path, "r", encoding="utf-8") as fh:
            settings = json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        _warn(f".claude/settings.json exists but couldn't be parsed: {exc}")
        settings = None
    if not isinstance(settings, dict) or not isinstance(settings.get("hooks", {}), dict):
        _warn("Skipping hook merge to avoid data loss — fix .claude/settings.json and re-run.")
        skipped.append(".claude/settings.json  ← unparseable or unexpected shape, skipped")
        return None
    return settings


def merge_settings_json(root, skipped, merged, dry_run=False):
    """
    Merge all STANDARD_HOOKS into <root>/.claude/settings.json.
    Preserves every existing key and hook. Never duplicates a hook entry.
    """
    settings_path = os.path.join(root, ".claude", "settings.json")
    settings = _load_settings(settings_path, skipped)
    if settings is None:
        return

    hooks_block = settings.setdefault("hooks", {})
    added = []

    for event_type, hook_entries in STANDARD_HOOKS.items():
        event_list = hooks_block.setdefault(event_type, [])
        if not isinstance(event_list, list):
            skipped.append(f".claude/settings.json  ← hooks.{event_type} is not a list, skipped")
            continue
        for entry in hook_entries:
            script = _script_of(entry)
            if _is_hook_present(event_list, script):
                skipped.append(f".claude/settings.json  ← already present: {event_type} {script}")
            else:
                event_list.append(entry)
                added.append(f"{event_type} {script}")

    if not added:
        return
    if not dry_run:
        try:
            os.makedirs(os.path.dirname(settings_path), exist_ok=True)
            with open(settings_path, "w", encoding="utf-8") as fh:
                json.dump(settings, fh, indent=2, ensure_ascii=False)
                fh.write("\n")
        except OSError as exc:
            _warn(f"Could not write .claude/settings.json: {exc}")
            return
    merged.extend(f".claude/settings.json  ← added hook: {name}" for name in added)


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

def copy_templates(root, created, skipped, dry_run):
    """Copy every template file that doesn't already exist at the target."""
    for src_dir, dirs, files in os.walk(TEMPLATES_DIR):
        dirs.sort()
        rel_dir = os.path.relpath(src_dir, TEMPLATES_DIR)
        for filename in sorted(files):
            rel_dest = os.path.normpath(os.path.join(rel_dir, filename))
            dst_file = os.path.join(root, rel_dest)
            # lexists: a dangling symlink still counts as "present" — never
            # write through it to wherever it points.
            if os.path.lexists(dst_file):
                skipped.append(rel_dest)
                continue
            if dry_run:
                created.append(rel_dest)
                continue
            try:
                os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                shutil.copy2(os.path.join(src_dir, filename), dst_file)
            except OSError as exc:
                _warn(f"Could not create {rel_dest}: {exc}")
                skipped.append(f"{rel_dest}  ← could not create")
                continue
            if filename.endswith(".sh"):
                mode = os.stat(dst_file).st_mode
                os.chmod(dst_file, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            created.append(rel_dest)


def audit_log_ignored(root):
    """True if a .gitignore at the root or in .claude/ mentions the audit log."""
    for rel in (".gitignore", os.path.join(".claude", ".gitignore")):
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as fh:
                if "command-audit.log" in fh.read():
                    return True
        except OSError:
            continue
    return False


def scaffold(target=None, dry_run=False):
    root = os.path.abspath(target or os.getcwd())
    mode = "dry run (nothing is written)" if dry_run else "non-destructive (existing files are never modified)"

    print("\n🏗️  ai-os-init scaffold")
    print(f"   Target : {root}")
    print(f"   Mode   : {mode}\n")

    created = []
    skipped = []
    merged = []

    copy_templates(root, created, skipped, dry_run)
    merge_settings_json(root, skipped, merged, dry_run)
    missing_sections = check_claude_md(root)
    bare = bare_source_dirs(root)

    verb = "Would create" if dry_run else "Created"
    _print_list("✅", verb, [f"+ {f}" for f in created])
    _print_list("🔀", "Would merge" if dry_run else "Merged", [f"~ {f}" for f in merged])
    _print_list("⏭️ ", "Skipped (already present)", [f"= {f}" for f in skipped])

    if missing_sections:
        print("\n💡 Your CLAUDE.md exists but is missing recommended sections:")
        for s in missing_sections:
            print(f"   {s}")
        print("   Consider adding them (see templates/CLAUDE.md for reference).")

    if bare:
        print("\n💡 Source dir(s) exist without a nested CLAUDE.md:")
        for d in bare:
            print(f"   {d}/CLAUDE.md — add sub-module context for better AI navigation")

    if not audit_log_ignored(root):
        print("\n💡 Add `.claude/command-audit.log` to .gitignore — audit-log.sh writes every")
        print("   bash command there, and commands can contain secrets.")

    if dry_run:
        print(f"\n🔎 Dry run: {len(created)} would be created, {len(merged)} merged, {len(skipped)} skipped.")
        return

    if not created and not merged:
        print(f"\n🟰 Already up to date: 0 created, 0 merged, {len(skipped)} skipped.")
        print("   Nothing to do — this project already has the full AI-OS structure.")
        return

    print(f"\n✨ Done: {len(created)} created, {len(merged)} merged, {len(skipped)} skipped.")
    print("\n📋 Next steps:")
    print("   1. Edit CLAUDE.md  — fill in project name, conventions, key commands")
    print("   2. Edit docs/architecture.md — describe your system's tech stack")
    print("   3. Try the new-adr skill: tell Claude 'create an ADR about [decision]'")
    print("   4. Try docs-auditor: tell Claude 'audit the docs'")
    print("   5. Open /hooks (or restart Claude Code) to confirm the new hooks are loaded")


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Scaffold the AI-OS layers into a project, non-destructively.")
    parser.add_argument("target", nargs="?", help="project directory (default: current directory)")
    parser.add_argument("--dry-run", action="store_true", help="list what would change without writing anything")
    args = parser.parse_args(argv)
    if args.target and not os.path.isdir(args.target):
        parser.error(f"target is not an existing directory: {args.target}")
    return args


# ──────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    scaffold(args.target, args.dry_run)
