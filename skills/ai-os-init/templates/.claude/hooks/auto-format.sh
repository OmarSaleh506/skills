#!/usr/bin/env bash
# auto-format — PostToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Runs the project's formatter on the file Claude just edited. Best-effort:
# never blocks, never prints, skips silently when no formatter is installed.
# Prefers a project-local formatter (node_modules/.bin) over a global one.

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

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Print the first available tool: project-local node binary, then PATH.
find_tool() {
  if [ -x "$ROOT/node_modules/.bin/$1" ]; then
    printf '%s\n' "$ROOT/node_modules/.bin/$1"
  elif command -v "$1" >/dev/null 2>&1; then
    command -v "$1"
  fi
}

case "${FILE##*.}" in
  py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format --quiet "$FILE" >/dev/null 2>&1
    elif command -v black >/dev/null 2>&1; then
      black --quiet "$FILE" >/dev/null 2>&1
    fi
    ;;
  js|jsx|mjs|cjs|ts|tsx|json|css|scss|html|vue|yaml|yml|md)
    PRETTIER=$(find_tool prettier)
    [ -n "$PRETTIER" ] && "$PRETTIER" --write "$FILE" >/dev/null 2>&1
    ;;
  go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" >/dev/null 2>&1
    ;;
  rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE" >/dev/null 2>&1
    ;;
esac

exit 0
