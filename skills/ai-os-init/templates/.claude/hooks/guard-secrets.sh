#!/usr/bin/env bash
# guard-secrets — PreToolUse hook
#
# Blocks Edit / Write / MultiEdit tool calls that target files whose paths
# look like they may contain secrets (env files, private keys, credentials).
#
# Wired via .claude/settings.json:
#   hooks.PreToolUse[].matcher  = "Edit|Write|MultiEdit"
#   hooks.PreToolUse[].hooks[].command = "bash .claude/hooks/guard-secrets.sh"
#
# Exit codes:
#   0 = allow (Claude proceeds with the tool call)
#   2 = block (Claude sees stdout as the reason; tool call is cancelled)
#
# Claude Code passes the tool-call JSON on stdin:
#   {"tool_name": "Edit", "tool_input": {"file_path": "/path/to/file", ...}}

# Capture stdin first (it's consumed once — save before piping)
INPUT=$(cat)

# Python parses JSON and checks patterns (Python 3 is always available)
printf '%s' "$INPUT" | python3 -c "
import json, re, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # malformed input — fail open (allow)

tool_input = data.get('tool_input') or {}
path = tool_input.get('file_path') or tool_input.get('path') or ''

if not path:
    sys.exit(0)  # no file path in this tool call — allow

# Patterns that indicate secret/credential files.
# Add more patterns here as your project needs them.
SECRET_PATTERNS = [
    r'\.env(\b|\.|/)',            # .env  .env.local  .env.production
    r'(^|[/\\\\])secrets[/\\\\]', # any secrets/ directory segment
    r'\.pem\$',                   # TLS/SSL private keys
    r'\.key\$',                   # generic private keys
    r'\.p12\$', r'\.pfx\$',       # PKCS12 keystores
    r'credentials',               # credentials.json, aws_credentials, etc.
    r'\.secret(\b|\.)',           # .secret  app.secret.json  etc.
    r'id_rsa\$', r'id_ed25519\$', r'id_ecdsa\$',  # SSH private keys
    r'kubeconfig',                # Kubernetes config files
    r'\.htpasswd\$',              # HTTP basic-auth password files
]

for pat in SECRET_PATTERNS:
    if re.search(pat, path, re.IGNORECASE):
        print(f'🔐 guard-secrets: Blocked write to suspected secret file.')
        print(f'   Path:    {path}')
        print(f'   Pattern: {pat}')
        print()
        print('   To allow this write, either:')
        print('   a) Remove the matching pattern from .claude/hooks/guard-secrets.sh')
        print('   b) Disable the hook in .claude/settings.json (remove the entry)')
        sys.exit(2)  # 2 = block / deny

sys.exit(0)  # allow
"
exit ${PIPESTATUS[1]}
