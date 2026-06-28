---
name: clean-tests
description: >-
  Audits and refactors existing test files for quality — removes brittle
  assertions, fixes implementation coupling (mocking internals), improves
  test names, eliminates duplication, and enforces behavior-over-implementation
  testing. Does NOT write new tests (use /tdd for that). Use when asked to
  "clean up the tests", "improve test quality", "fix brittle tests", "refactor
  the test suite", "tests keep breaking on refactor", "tests are a mess", or
  "make the tests better".
---

# clean-tests

Audits and refactors existing tests without removing coverage.

## What Gets Fixed

| Issue | Symptom | Fix |
|---|---|---|
| **Implementation coupling** | Mocking internal modules, testing private methods, asserting on internal state | Rewrite to test through public API only |
| **Brittle assertions** | Exact error message strings, hardcoded IDs, timestamp comparisons | Use flexible matchers, freeze time, assert structure not exact value |
| **Poor test names** | `test_1`, `test_user`, `testGetUser` | Rewrite as sentences: `returns_404_when_user_not_found` |
| **Multi-assertion tests** | One test checks 5 things — failure is ambiguous | Split into focused single-assertion tests |
| **Duplicated setup** | Same 15-line setup repeated across every test | Extract to fixture/factory/helper |
| **False confidence** | `assert True`, `assert result is not None`, empty tests | Add meaningful behavioral assertions |
| **Order dependence** | Tests pass together but fail in isolation | Make each test fully self-contained |
| **Flaky time/random** | `datetime.now()` or `random()` in assertions | Freeze time, seed random, or use matchers |

## Process

### 1. Discover test files

```bash
find . -type f \( -name "test_*.py" -o -name "*_test.py" -o -name "*.test.ts" -o -name "*.spec.ts" -o -name "*.test.tsx" -o -name "*.spec.tsx" \) \
  | grep -v node_modules | grep -v .venv | grep -v dist | sort
```

### 2. Analyze → Prioritize → Fix → Run tests after each file

Fix order: implementation coupling → poor naming → brittle assertions → duplication → false confidence.

Run tests after every file:
```bash
pytest <file> -x -q 2>&1 | tail -8   # Python
npx vitest run <file> 2>&1 | tail -8  # JS/TS
```

### 3. Rules

- Never delete a test — only improve it
- Never change WHAT a test asserts about behavior, only HOW
- If a fix is uncertain, leave `# TODO clean-tests: <reason>` rather than breaking coverage
- Run tests after every file before moving to the next

### 4. Report findings at the end with counts per category
