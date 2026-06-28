#!/usr/bin/env bash
# PostToolUse — fires after Edit/Write/MultiEdit
# Scans the modified file for likely N+1 query patterns:
# a database call found inside a for loop body.
# Best-effort heuristic — warns but never blocks.

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
    python3 - "$FILE" <<'PYEOF'
import re, sys
from pathlib import Path

src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
lines = src.splitlines()
warnings = []

DB_RE = re.compile(
    r"await\s+session\.(execute|get|scalar|scalars|refresh|run_sync)"
    r"|session\.execute\("
    r"|await\s+db\.(execute|get|scalar)"
    r"|await\s+\w+_session\.(execute|get|scalar)"
)
LOOP_RE = re.compile(r"^\s*(for\s+\S.*\s+in\s+|async\s+for\s+)")

for i, line in enumerate(lines):
    if LOOP_RE.match(line):
        loop_indent = len(line) - len(line.lstrip())
        for j in range(i + 1, min(i + 12, len(lines))):
            nxt = lines[j]
            if not nxt.strip():
                continue
            nxt_indent = len(nxt) - len(nxt.lstrip())
            if nxt_indent <= loop_indent:
                break
            if DB_RE.search(nxt):
                warnings.append(
                    f"  line {j+1}: DB call inside loop (loop at line {i+1}): {nxt.strip()[:90]}"
                )
                break

if warnings:
    print(f"[n+1-guard] Possible N+1 in {sys.argv[1]}:")
    for w in warnings:
        print(w)
    print("  Fix: selectinload()/joinedload() on the outer query, or batch with .in_().")
PYEOF
    ;;
  ts|tsx|js|jsx)
    python3 - "$FILE" <<'PYEOF'
import re, sys
from pathlib import Path

src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
lines = src.splitlines()
warnings = []

DB_RE = re.compile(
    r"await\s+\w+\.(find|findOne|findById|findAll|findMany|create|update|delete|query|execute)\s*\("
    r"|prisma\.\w+\.(find|create|update|delete|upsert)"
    r"|\.query\s*\("
)
LOOP_RE = re.compile(r"\b(for\s*\(|for\s+\w+\s+of\s+|\.forEach\s*\()")

brace_depth = 0
in_loop_at = None

for i, line in enumerate(lines):
    opens = line.count("{")
    closes = line.count("}")
    if LOOP_RE.search(line):
        in_loop_at = brace_depth + opens - closes
    brace_depth += opens - closes
    if in_loop_at is not None:
        if brace_depth <= in_loop_at:
            in_loop_at = None
        elif DB_RE.search(line):
            warnings.append(f"  line {i+1}: DB call inside loop: {line.strip()[:90]}")
            in_loop_at = None

if warnings:
    print(f"[n+1-guard] Possible N+1 in {sys.argv[1]}:")
    for w in warnings:
        print(w)
    print("  Fix: eager load or batch IDs with an IN clause outside the loop.")
PYEOF
    ;;
esac

exit 0
