#!/usr/bin/env bash
# PostToolUse — fires after Edit/Write/MultiEdit
# Silently runs the project's formatter on the modified file.
# Never blocks, never fails loudly — formatting is best-effort.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print((d.get('tool_input') or {}).get('file_path', ''))
" 2>/dev/null)

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

EXT="${FILE##*.}"

case "$EXT" in
  py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format --quiet "$FILE" 2>/dev/null
    elif command -v black >/dev/null 2>&1; then
      black --quiet "$FILE" 2>/dev/null
    fi
    ;;
  js|jsx|ts|tsx|json|css|scss|html|yaml|yml|md)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write --log-level silent "$FILE" 2>/dev/null
    fi
    ;;
  go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" 2>/dev/null
    ;;
  rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt --quiet "$FILE" 2>/dev/null
    ;;
esac

exit 0
