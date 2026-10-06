#!/usr/bin/env bash
# guard-secrets — PreToolUse hook (matcher: Edit|Write|MultiEdit)
#
# Blocks writes to files whose names look like they hold secrets: env files,
# private keys, credential stores, kubeconfigs. Example/template files such as
# .env.example or credentials.sample.json are allowed — they're meant to be
# committed.
#
# Contract (https://code.claude.com/docs/en/hooks):
#   stdin  : {"tool_name": "Edit", "tool_input": {"file_path": "/abs/path", ...}, ...}
#   exit 0 : allow
#   exit 2 : block — stderr is shown to Claude as the reason
#
# Fails open (allows) if python3 is missing or the input can't be parsed.

command -v python3 >/dev/null 2>&1 || exit 0

HOOK_INPUT=$(cat) python3 - <<'PY'
import json
import os
import re
import sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT", ""))
except ValueError:
    sys.exit(0)

tool_input = data.get("tool_input") or {}
path = tool_input.get("file_path") or tool_input.get("path") or ""
if not path:
    sys.exit(0)

name = os.path.basename(path).lower()
segments = [s.lower() for s in re.split(r"[/\\]", path)]

# Committed placeholders, not real secrets.
ALLOWED_SUFFIXES = (".example", ".sample", ".template", ".dist", ".md")
for suffix in ALLOWED_SUFFIXES:
    if name.endswith(suffix) or f"{suffix}." in name:
        sys.exit(0)

# (reason, test) — tests run on the lowercased basename unless noted.
SECRET_RULES = [
    ("env file", lambda: name == ".env" or name.startswith(".env.") or name.endswith(".env")),
    ("private key / keystore", lambda: name.endswith((".pem", ".key", ".p12", ".pfx", ".jks", ".keystore"))),
    ("SSH private key", lambda: re.fullmatch(r"id_(rsa|dsa|ecdsa|ed25519)", name) is not None),
    ("credentials file", lambda: re.fullmatch(r"credentials(\.(json|ya?ml|xml|ini|toml))?", name) is not None),
    ("secret file", lambda: re.fullmatch(r"(.*[._-])?secrets?(\.(json|ya?ml|toml|ini|txt|env|conf))?", name) is not None),
    ("secrets/ directory", lambda: "secrets" in segments[:-1]),
    ("kubeconfig", lambda: name.startswith("kubeconfig") or segments[-2:] == [".kube", "config"]),
    ("htpasswd file", lambda: name == ".htpasswd"),
    ("netrc / pgpass", lambda: name in (".netrc", ".pgpass")),
]

for reason, matches in SECRET_RULES:
    if matches():
        print(
            f"guard-secrets: blocked write to {path} (looks like a {reason}).\n"
            "Secrets don't belong in files Claude edits. Ask the user to make this change "
            "themselves, or remove the rule from .claude/hooks/guard-secrets.sh if it's a false positive.",
            file=sys.stderr,
        )
        sys.exit(2)

sys.exit(0)
PY
