#!/usr/bin/env bash
# PostToolUse — fires after Edit/Write/MultiEdit
# Runs the project's type checker on the modified file and surfaces errors
# so Claude can fix them immediately. Skips silently if no checker is configured.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print((d.get('tool_input') or {}).get('file_path', ''))
" 2>/dev/null)

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

EXT="${FILE##*.}"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

case "$EXT" in
  ts|tsx)
    # Only run if tsconfig.json exists (project has TypeScript configured)
    if [ -f "$ROOT/tsconfig.json" ] && command -v tsc >/dev/null 2>&1; then
      ERRORS=$(cd "$ROOT" && tsc --noEmit 2>&1 | head -20)
      if [ -n "$ERRORS" ]; then
        echo "[typecheck] TypeScript errors detected:"
        echo "$ERRORS"
      fi
    fi
    ;;
  py)
    # Only run if mypy config exists
    HAS_MYPY=0
    [ -f "$ROOT/mypy.ini" ] && HAS_MYPY=1
    [ -f "$ROOT/.mypy.ini" ] && HAS_MYPY=1
    grep -q '\[tool\.mypy\]' "$ROOT/pyproject.toml" 2>/dev/null && HAS_MYPY=1

    if [ "$HAS_MYPY" = "1" ] && command -v mypy >/dev/null 2>&1; then
      ERRORS=$(mypy --ignore-missing-imports --no-error-summary "$FILE" 2>&1 \
               | grep -v '^Success' | grep -v '^Found 0 errors' | head -20)
      if [ -n "$ERRORS" ]; then
        echo "[typecheck] mypy errors in $FILE:"
        echo "$ERRORS"
      fi
    fi
    ;;
esac

exit 0
