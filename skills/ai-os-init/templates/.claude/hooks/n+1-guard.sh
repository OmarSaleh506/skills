#!/usr/bin/env bash
# n+1-guard — PostToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Heuristic: flags a database call that sits inside a loop body in the file
# Claude just edited (.py / .js / .ts and friends). Warns, never blocks.
#
# Warnings are returned as JSON `hookSpecificOutput.additionalContext`, which
# Claude reads; plain stdout from a PostToolUse hook only reaches the debug log
# (https://code.claude.com/docs/en/hooks).

command -v python3 >/dev/null 2>&1 || exit 0

HOOK_INPUT=$(cat) python3 - <<'PY'
import json
import os
import re
import sys

LOOKAHEAD_LINES = 12
MAX_WARNINGS = 10

PY_DB = re.compile(
    r"\bsession\.(execute|get|scalar|scalars|refresh|query)\("
    r"|\b\w+_session\.(execute|get|scalar|scalars)\("
    r"|\bawait\s+db\.(execute|get|scalar|fetch\w*)\("
    r"|\.objects\.(get|filter|create|exclude)\("
)
PY_LOOP = re.compile(r"^\s*(async\s+)?for\s+.+\s+in\s+.+:\s*(#.*)?$")

JS_DB = re.compile(
    r"\bawait\s+[\w.]+\.(find\w*|create|update\w*|delete\w*|upsert|query|execute)\s*\("
    r"|\bprisma\.\w+\.(find\w*|create|update\w*|delete\w*|upsert)\s*\("
)
JS_LOOP = re.compile(r"\bfor\s*(await\s*)?\(|\bwhile\s*\(|\.forEach\s*\(")


def indent_of(line):
    return len(line) - len(line.lstrip())


def scan_python(lines):
    hits = []
    for i, line in enumerate(lines):
        if not PY_LOOP.match(line):
            continue
        loop_indent = indent_of(line)
        for j in range(i + 1, min(i + 1 + LOOKAHEAD_LINES, len(lines))):
            body = lines[j]
            if not body.strip():
                continue
            if indent_of(body) <= loop_indent:
                break
            if PY_DB.search(body):
                hits.append((j + 1, i + 1, body.strip()))
                break
    return hits


def scan_js(lines):
    hits = []
    depth = 0
    loop_depth = None  # brace depth just outside the innermost tracked loop
    loop_line = None
    for i, line in enumerate(lines):
        if loop_depth is None and JS_LOOP.search(line):
            loop_depth, loop_line = depth, i + 1
        if loop_depth is not None and JS_DB.search(line):
            hits.append((i + 1, loop_line, line.strip()))
            loop_depth = None
        depth += line.count("{") - line.count("}")
        if loop_depth is not None and depth <= loop_depth and i + 1 > loop_line:
            loop_depth = None
    return hits


try:
    data = json.loads(os.environ.get("HOOK_INPUT", ""))
except ValueError:
    sys.exit(0)

path = (data.get("tool_input") or {}).get("file_path") or ""
ext = os.path.splitext(path)[1].lower()
scanners = {".py": scan_python}
scanners.update(dict.fromkeys((".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx"), scan_js))
if ext not in scanners or not os.path.isfile(path):
    sys.exit(0)

with open(path, encoding="utf-8", errors="replace") as fh:
    hits = scanners[ext](fh.read().splitlines())
if not hits:
    sys.exit(0)

report = [f"[n+1-guard] Possible N+1 query in {path} (heuristic — ignore if intentional):"]
for line_no, loop_no, text in hits[:MAX_WARNINGS]:
    report.append(f"  line {line_no}: DB call inside loop started at line {loop_no}: {text[:90]}")
report.append("  Fix: eager-load on the outer query, or batch the IDs into one IN (...) query outside the loop.")

print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "\n".join(report)}}))
PY
exit 0
