#!/usr/bin/env bash
# PreToolUse — fires before Bash
#
# Guards (in order):
#  1. Block force push
#  2. Block direct push/commit to protected branches (main/master/develop/staging/production)
#  3. Pre-push: warn if branch has > 1 commit — keep one focused commit per branch
#  4. Pre-push: run local CI checks so the remote workflow doesn't fail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print((d.get('tool_input') or {}).get('command', ''))
" 2>/dev/null)

[ -z "$CMD" ] && exit 0

PROTECTED_RE='main|master|develop|staging|production'

# ── 1. Block force push ──────────────────────────────────────────────────────
if printf '%s' "$CMD" | grep -qE 'git push.*(--force|-f )'; then
  echo "🛡️  branch-guard: Blocked force push."
  echo "   Only use --force-with-lease if you genuinely need it, and explain why."
  exit 2
fi

# ── 2. Block direct push to protected branches ──────────────────────────────
if printf '%s' "$CMD" | grep -qE "git push[^|&;]*\\b($PROTECTED_RE)\\b"; then
  BRANCH=$(printf '%s' "$CMD" | grep -oE "\\b($PROTECTED_RE)\\b" | head -1)
  echo "🛡️  branch-guard: Blocked direct push to '$BRANCH'."
  echo "   Open a PR from your feature branch instead."
  exit 2
fi

# ── 3. Block commit directly on a protected branch ──────────────────────────
if printf '%s' "$CMD" | grep -qE '^[[:space:]]*git commit'; then
  CURRENT=$(git branch --show-current 2>/dev/null)
  if printf '%s' "$CURRENT" | grep -qE "^($PROTECTED_RE)$"; then
    echo "🛡️  branch-guard: Blocked commit directly on '$CURRENT'."
    echo "   Create a feature branch: git checkout -b feat/your-change"
    exit 2
  fi
fi

# ── 4. Pre-push: single-commit warning + CI checks ──────────────────────────
if printf '%s' "$CMD" | grep -qE 'git push'; then

  # 4a. Warn if branch has more than one commit ahead of base
  BASE=""
  for b in main master develop staging; do
    if git rev-parse --verify "origin/$b" >/dev/null 2>&1; then
      BASE="origin/$b"; break
    fi
  done
  if [ -n "$BASE" ]; then
    COUNT=$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)
    if [ "$COUNT" -gt 1 ]; then
      echo "⚠️  branch-guard: Branch has $COUNT commits ahead of $BASE."
      echo "   One focused commit per feature branch keeps history clean."
      echo "   To squash: git rebase -i $BASE"
      echo "   (Proceeding — this is a warning, not a block.)"
      echo ""
    fi
  fi

  # 4b. Run local CI checks — same checks the remote workflow runs
  CI_CMD=""
  CI_LABEL=""

  # Detect the project's CI check command
  if [ -f "Makefile" ] && grep -q '^check:' Makefile 2>/dev/null; then
    CI_CMD="make check"
    CI_LABEL="make check"
  elif [ -f "package.json" ]; then
    HAS_LINT=$(python3 -c "
import json, sys
s = json.load(open('package.json')).get('scripts', {})
print('1' if 'lint' in s or 'typecheck' in s else '')
" 2>/dev/null)
    if [ "$HAS_LINT" = "1" ]; then
      CI_CMD="npm run lint && npm run typecheck"
      CI_LABEL="npm run lint + typecheck"
    fi
  elif [ -f "pyproject.toml" ] && command -v ruff >/dev/null 2>&1; then
    CI_CMD="ruff check . && ruff format --check ."
    CI_LABEL="ruff check + format --check"
  fi

  if [ -n "$CI_CMD" ]; then
    echo "🔍 branch-guard: Running CI checks before push ($CI_LABEL)…"
    echo ""
    if eval "$CI_CMD"; then
      echo ""
      echo "✅ branch-guard: All checks passed — proceeding with push."
    else
      echo ""
      echo "❌ branch-guard: CI checks FAILED. Fix the errors above before pushing."
      echo "   The remote workflow will fail with the same errors."
      exit 2
    fi
  fi

fi

exit 0
