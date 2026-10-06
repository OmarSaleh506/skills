#!/usr/bin/env bash
# audit-log — PostToolUse hook (matcher: Bash)
#
# Appends every bash command Claude runs to .claude/command-audit.log at the
# project root. Never blocks, never prints. Commands can contain secrets, so
# keep the log out of git (add `.claude/command-audit.log` to .gitignore).

command -v python3 >/dev/null 2>&1 || exit 0

CMD=$(python3 -c '
import json, sys
try:
    cmd = (json.load(sys.stdin).get("tool_input") or {}).get("command", "")
except ValueError:
    sys.exit(0)
print(" ".join(cmd.split())[:400])
' 2>/dev/null)

[ -z "$CMD" ] && exit 0

LOG_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CMD" >> "$LOG_DIR/command-audit.log" 2>/dev/null

exit 0
