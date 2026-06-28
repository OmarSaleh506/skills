#!/usr/bin/env bash
# PostToolUse — fires after Bash
# Silently appends every command Claude runs to .claude/command-audit.log
# Never blocks. Useful for reviewing what Claude did in a session.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
cmd = (d.get('tool_input') or {}).get('command', '').strip()
# Collapse whitespace and truncate at 400 chars
cmd = ' '.join(cmd.split())[:400]
print(cmd)
" 2>/dev/null)

[ -z "$CMD" ] && exit 0

LOG=".claude/command-audit.log"
mkdir -p ".claude"
printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CMD" >> "$LOG" 2>/dev/null

exit 0
