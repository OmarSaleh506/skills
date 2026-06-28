#!/usr/bin/env bash
# shop-scout Firecrawl wrapper — auto-detects backend and runs /search or /scrape.
#
# Backend detection mirrors SKILL.md:
#   FIRECRAWL_API_URL set  -> self-host (no auth)
#   else FIRECRAWL_API_KEY -> cloud (Bearer auth)
#   else                   -> error (use your agent's native web tools instead)
#
# The API key is read from the environment and is NEVER printed. Output is the
# raw Firecrawl JSON on stdout; check the `success` field. Needs only curl.
#
# Usage:
#   firecrawl.sh search "<query>" [limit]
#   firecrawl.sh scrape "<url>" [country]
set -eo pipefail

err() { printf '%s\n' "$*" >&2; }

if [ "${SHOP_BACKEND:-auto}" = "builtin" ]; then
  err "SHOP_BACKEND=builtin: this script is Firecrawl-only. Use your agent's native web search/fetch."
  exit 2
fi

auth_args=()
if [ -n "${FIRECRAWL_API_URL:-}" ]; then
  base="${FIRECRAWL_API_URL%/}/v2"                       # self-host, no auth header
elif [ -n "${FIRECRAWL_API_KEY:-}" ]; then
  base="https://api.firecrawl.dev/v2"                    # cloud
  auth_args=(-H "Authorization: Bearer ${FIRECRAWL_API_KEY}")
else
  err "No Firecrawl backend: set FIRECRAWL_API_URL (self-host) or FIRECRAWL_API_KEY (cloud)."
  exit 2
fi

# JSON-encode a string safely (jq > python3 > minimal sed fallback).
json_str() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rs .
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  else
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  fi
}

post() { # $1=path $2=json-body
  curl -sS --max-time 90 -X POST "$base/$1" \
    "${auth_args[@]+"${auth_args[@]}"}" \
    -H 'Content-Type: application/json' -d "$2"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  search)
    q="${1:-}"; limit="${2:-5}"
    [ -n "$q" ] || { err 'usage: firecrawl.sh search "<query>" [limit]'; exit 2; }
    post search "{\"query\":$(json_str "$q"),\"limit\":${limit},\"sources\":[\"web\"]}"
    ;;
  scrape)
    url="${1:-}"; country="${2:-}"
    [ -n "$url" ] || { err 'usage: firecrawl.sh scrape "<url>" [country]'; exit 2; }
    loc=""
    [ -n "$country" ] && loc=",\"location\":{\"country\":$(json_str "$country")}"
    post scrape "{\"url\":$(json_str "$url"),\"formats\":[\"markdown\"],\"onlyMainContent\":true${loc}}"
    ;;
  *)
    err 'usage: firecrawl.sh {search "<query>" [limit] | scrape "<url>" [country]}'
    exit 2
    ;;
esac
