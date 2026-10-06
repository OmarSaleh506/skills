#!/usr/bin/env bash
# typecheck — PostToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Runs the project's type checker after Claude edits a .ts/.tsx/.py file and
# hands any errors back to Claude so it can fix them right away. Skips silently
# unless the project is configured for it (tsconfig.json / mypy config) and the
# checker is installed. Never blocks.
#
# Errors are returned as JSON `hookSpecificOutput.additionalContext`, which
# Claude reads; plain stdout from a PostToolUse hook only reaches the debug log
# (https://code.claude.com/docs/en/hooks).

command -v python3 >/dev/null 2>&1 || exit 0

FILE=$(python3 -c '
import json, sys
try:
    print((json.load(sys.stdin).get("tool_input") or {}).get("file_path", ""))
except ValueError:
    pass
' 2>/dev/null)

[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MAX_LINES=20

emit_context() {
  printf '%s' "$1" | python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.stdin.read()}}))
'
}

case "${FILE##*.}" in
  ts|tsx)
    [ -f "$ROOT/tsconfig.json" ] || exit 0
    if [ -x "$ROOT/node_modules/.bin/tsc" ]; then
      TSC="$ROOT/node_modules/.bin/tsc"
    elif command -v tsc >/dev/null 2>&1; then
      TSC=tsc
    else
      exit 0
    fi
    ERRORS=$(cd "$ROOT" && "$TSC" --noEmit --pretty false 2>&1 | grep 'error TS' | head -n "$MAX_LINES")
    [ -n "$ERRORS" ] && emit_context "[typecheck] TypeScript errors after editing $FILE:
$ERRORS"
    ;;
  py)
    command -v mypy >/dev/null 2>&1 || exit 0
    HAS_MYPY=0
    [ -f "$ROOT/mypy.ini" ] && HAS_MYPY=1
    [ -f "$ROOT/.mypy.ini" ] && HAS_MYPY=1
    grep -q '^\[mypy\]' "$ROOT/setup.cfg" 2>/dev/null && HAS_MYPY=1
    grep -q '^\[tool\.mypy\]' "$ROOT/pyproject.toml" 2>/dev/null && HAS_MYPY=1
    [ "$HAS_MYPY" = "1" ] || exit 0
    ERRORS=$(cd "$ROOT" && mypy --ignore-missing-imports --no-error-summary "$FILE" 2>&1 \
             | grep ': error:' | head -n "$MAX_LINES")
    [ -n "$ERRORS" ] && emit_context "[typecheck] mypy errors in $FILE:
$ERRORS"
    ;;
esac

exit 0
