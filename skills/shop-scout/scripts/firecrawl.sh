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
#   firecrawl.sh --help
#
# Env:
#   FIRECRAWL_MAX_AGE_MS  scrape cache max age in ms (default 0 = always fresh;
#                         Firecrawl's own default caches pages for 2 days, which
#                         would serve stale prices).
#   FIRECRAWL_RETRIES     retries on HTTP 429/5xx/network error (default 2).
#
# Exit codes: 0 ok, 2 usage/config problem, 3 HTTP/network failure.
set -eo pipefail

err() { printf '%s\n' "$*" >&2; }

usage() {
  err 'usage: firecrawl.sh {search "<query>" [limit] | scrape "<url>" [country]}'
  err 'backend: set FIRECRAWL_API_URL (self-host) or FIRECRAWL_API_KEY (cloud).'
}

case "${1:-}" in -h|--help|help) usage; exit 0 ;; esac

if ! command -v curl >/dev/null 2>&1; then
  err "curl not found: this wrapper needs curl. Use your agent's native web tools instead."
  exit 2
fi

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

# POST with retry on 429/5xx/network error. Body goes to stdout; failures are
# explained on stderr and return 3.
post() { # $1=path $2=json-body
  local retries="${FIRECRAWL_RETRIES:-2}" attempt=0 out code body
  while :; do
    out="$(curl -sS --max-time 90 -X POST "$base/$1" \
      "${auth_args[@]+"${auth_args[@]}"}" \
      -H 'Content-Type: application/json' -d "$2" \
      -w '\n%{http_code}' 2>/dev/null)" || out=$'\n000'
    code="${out##*$'\n'}"
    body="${out%$'\n'*}"
    case "$code" in
      2??) printf '%s\n' "$body"; return 0 ;;
      429|5??|000)
        if [ "$attempt" -lt "$retries" ]; then
          attempt=$((attempt + 1)); sleep $((attempt * 3)); continue
        fi ;;
    esac
    case "$code" in
      401) err "HTTP 401: bad or missing FIRECRAWL_API_KEY." ;;
      402) err "HTTP 402: Firecrawl cloud credits exhausted." ;;
      429) err "HTTP 429: rate limited; lower SHOP_PARALLEL and retry later." ;;
      000) err "Network error: backend unreachable (is the self-host stack up?)." ;;
      *)   err "HTTP $code from Firecrawl." ;;
    esac
    [ "$code" = 000 ] || printf '%s\n' "$body"
    return 3
  done
}

cmd="${1:-}"; shift || true
case "$cmd" in
  search)
    q="${1:-}"; limit="${2:-5}"
    [ -n "$q" ] || { usage; exit 2; }
    case "$limit" in ''|*[!0-9]*) err "limit must be a positive integer"; exit 2 ;; esac
    post search "{\"query\":$(json_str "$q"),\"limit\":${limit},\"sources\":[\"web\"]}"
    ;;
  scrape)
    url="${1:-}"; country="${2:-}"
    [ -n "$url" ] || { usage; exit 2; }
    max_age="${FIRECRAWL_MAX_AGE_MS:-0}"
    case "$max_age" in ''|*[!0-9]*) err "FIRECRAWL_MAX_AGE_MS must be an integer"; exit 2 ;; esac
    loc=""
    [ -n "$country" ] && loc=",\"location\":{\"country\":$(json_str "$country")}"
    post scrape "{\"url\":$(json_str "$url"),\"formats\":[\"markdown\"],\"onlyMainContent\":true,\"maxAge\":${max_age}${loc}}"
    ;;
  *)
    usage
    exit 2
    ;;
esac
