#!/usr/bin/env bash
# verify.sh — Mechanical quality checks
# Run before review to catch obvious issues.
# Exit code 0 = all OK, otherwise list of errors.
#
# Modes:
#   bash verify.sh          — auto-detect: staged if staged files exist, else working tree
#   bash verify.sh --staged — force staged mode (git diff --cached)
#   bash verify.sh --ci     — CI mode: diff against base branch (main/master)
#
# TODO: Customize checks for your project's tech stack.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=()
WARNINGS=()
MISSING_TESTS=()

# ─── Helpers ───────────────────────────────────────────────────────

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ERRORS+=("$1"); }
warn() { echo "  ⚠ $1"; WARNINGS+=("$1"); }
section() { echo ""; echo "── $1 ──"; }

# ─── Determine diff mode ──────────────────────────────────────────

MODE="${1:-auto}"
case "$MODE" in
  --staged)
    DIFF_FILES=$(git diff --cached --name-only 2>/dev/null || true)
    DIFF_CONTENT=$(git diff --cached 2>/dev/null || true)
    DIFF_CMD_FILE="git diff --cached"
    echo "Mode: staged changes"
    ;;
  --ci)
    BASE="main"
    if ! git rev-parse --verify "$BASE" &>/dev/null; then
      BASE="master"
    fi
    DIFF_FILES=$(git diff "$BASE"...HEAD --name-only 2>/dev/null || true)
    DIFF_CONTENT=$(git diff "$BASE"...HEAD 2>/dev/null || true)
    DIFF_CMD_FILE="git diff $BASE...HEAD"
    echo "Mode: CI (diff against $BASE)"
    ;;
  *)
    STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l || echo 0)
    if [ "$STAGED_COUNT" -gt 0 ]; then
      DIFF_FILES=$(git diff --cached --name-only 2>/dev/null || true)
      DIFF_CONTENT=$(git diff --cached 2>/dev/null || true)
      DIFF_CMD_FILE="git diff --cached"
      echo "Mode: staged changes (auto-detected)"
    else
      DIFF_FILES=$(git diff --name-only 2>/dev/null || true)
      DIFF_CONTENT=$(git diff 2>/dev/null || true)
      DIFF_CMD_FILE="git diff"
      echo "Mode: working tree (auto-detected)"
    fi
    ;;
esac

# ─── 1. Type checking ────────────────────────────────────────────

section "Type Check"

# TODO: Add your project's type checking command
# Examples:
#   npx tsc --noEmit
#   pnpm turbo typecheck
#   mypy .
#   go vet ./...
warn "Type check not configured — add your typecheck command to verify.sh"

# ─── 2. Linting ──────────────────────────────────────────────────

section "Lint"

# TODO: Add your project's linting command
# Examples:
#   npx eslint src/
#   ruff check .
#   golangci-lint run
warn "Linting not configured — add your lint command to verify.sh"

# ─── 3. Tests ────────────────────────────────────────────────────

section "Tests"

# TODO: Add your project's test commands
# Examples:
#   npm test -- --passWithNoTests
#   pytest
#   go test ./...
warn "Test execution not configured — add your test command to verify.sh"

# ─── 4. Secrets check ────────────────────────────────────────────

section "Secrets Check"

if [ -n "$DIFF_FILES" ]; then
  SECRETS_FOUND=false

  # Compute the set of files that are *deleted* in this diff. Removing a
  # tracked secret file is the fix, not the bug — we must not flag those
  # even when the working tree still has a local copy.
  case "$MODE" in
    --staged)
      DELETED_FILES=$(git diff --cached --diff-filter=D --name-only 2>/dev/null || true)
      ;;
    --ci)
      DELETED_FILES=$(git diff "$BASE"...HEAD --diff-filter=D --name-only 2>/dev/null || true)
      ;;
    *)
      if [ "${STAGED_COUNT:-0}" -gt 0 ]; then
        DELETED_FILES=$(git diff --cached --diff-filter=D --name-only 2>/dev/null || true)
      else
        DELETED_FILES=$(git diff --diff-filter=D --name-only 2>/dev/null || true)
      fi
      ;;
  esac

  is_deleted_in_diff() {
    [ -z "$DELETED_FILES" ] && return 1
    echo "$DELETED_FILES" | grep -qxF "$1"
  }

  # Block .env files — but not template/example files, and not pure deletions
  # (deleting a tracked .env is how we clean up leaked secrets).
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    base=$(basename "$file")
    # Template/example files are safe — they contain placeholders by design
    if [[ "$base" == *.example ]] || [[ "$base" == *.sample ]] || [[ "$base" == *.template ]]; then
      continue
    fi
    # File deletions are safe — removing a leaked secret is the fix.
    if [ ! -e "$file" ] || is_deleted_in_diff "$file"; then
      continue
    fi
    if [[ "$file" =~ ^\.env(\..+)?$ ]] || [[ "$base" =~ ^\.env(\..+)?$ ]]; then
      fail "Changed secret file: $file"
      SECRETS_FOUND=true
    fi
  done <<< "$DIFF_FILES"

  # Pattern-based secret detection in diffs.
  # Exclude documentation, env-templates, and the gitleaks config (which
  # describes pattern shapes in comments, so it would match itself).
  SECRET_SCAN_FILES=$(echo "$DIFF_FILES" \
    | grep -vE '\.(md|yml|yaml)$' \
    | grep -v '^\.ai/' \
    | grep -vE '\.(example|sample|template)$' \
    | grep -v '^\.githooks/' \
    | grep -v '^\.gitleaks\.toml$' \
    || true)

  if [ -n "$SECRET_SCAN_FILES" ]; then
    SECRET_DIFF=""
    while IFS= read -r sfile; do
      [ -z "$sfile" ] && continue
      SECRET_DIFF+=$($DIFF_CMD_FILE -- "$sfile" 2>/dev/null || true)
    done <<< "$SECRET_SCAN_FILES"

    SECRET_PATTERNS=(
      "_SECRET=['\"]?.{8,}"
      "_API_KEY=['\"]?.{8,}"
      "ANTHROPIC_API_KEY=.+"
      "OPENAI_API_KEY=.+"
      "JWT_SECRET=.+"
      "DATABASE_URL=.*:.*@"
      "password['\"]?\\s*[:=]\\s*['\"].{6,}"
    )

    for pattern in "${SECRET_PATTERNS[@]}"; do
      if echo "$SECRET_DIFF" | grep '^+' | grep -qE "$pattern"; then
        fail "Diff contains potential secret matching: $pattern"
        SECRETS_FOUND=true
      fi
    done
  fi

  if [ "$SECRETS_FOUND" = false ]; then
    pass "No secrets in changed files"
  fi
else
  pass "No changed files to check"
fi

# ─── 5. Scope check ─────────────────────────────────────────────

section "Scope Check"

if [ -n "$DIFF_FILES" ]; then
  # Diff size check
  DIFF_LINES=$(echo "$DIFF_CONTENT" | grep -c '^[+-]' || true)
  if [ "$DIFF_LINES" -gt 500 ]; then
    warn "Large diff ($DIFF_LINES changed lines) — consider splitting into smaller PRs"
  fi

  # Plan-based scope check
  if [ -f ".ai/logs/planned-files.txt" ]; then
    UNPLANNED=()
    while IFS= read -r changed; do
      [ -z "$changed" ] && continue
      [[ "$changed" == *.test.* ]] && continue
      [[ "$changed" == *.spec.* ]] && continue
      [[ "$changed" == *_test.* ]] && continue
      [[ "$changed" == *.md ]] && continue
      [[ "$changed" == ".ai/"* ]] && continue

      if ! grep -qF "$changed" .ai/logs/planned-files.txt; then
        UNPLANNED+=("$changed")
      fi
    done <<< "$DIFF_FILES"

    if [ ${#UNPLANNED[@]} -gt 0 ]; then
      for uf in "${UNPLANNED[@]}"; do
        warn "Unplanned file changed: $uf — verify this is related to the issue"
      done
    else
      pass "All changed files match plan"
    fi
  fi

  pass "Scope check done"
fi

# ─── 6. Test requirements gate ───────────────────────────────────

section "Test Requirements"

# TODO: Customize test requirement patterns for your project.
# The logic below is a generic example — adjust file extensions,
# paths, and test file naming conventions.

is_test_exempt() {
  local f="$1"
  [[ "$f" == *.css ]] && return 0
  [[ "$f" == *.scss ]] && return 0
  [[ "$f" == *.md ]] && return 0
  [[ "$f" == *.yml ]] && return 0
  [[ "$f" == *.yaml ]] && return 0
  [[ "$f" == *.json ]] && return 0
  [[ "$f" == *.sh ]] && return 0
  [[ "$f" == *".d.ts" ]] && return 0
  [[ "$f" == ".ai/"* ]] && return 0
  [[ "$f" == ".claude/"* ]] && return 0
  [[ "$f" == ".github/"* ]] && return 0
  return 1
}

if [ -n "$DIFF_FILES" ]; then
  # Check source files for matching test files
  SRC_FILES=$(echo "$DIFF_FILES" | grep -E '\.(ts|tsx|js|jsx|py|go)$' | grep -v '\.test\.' | grep -v '\.spec\.' | grep -v '_test\.' || true)
  if [ -n "$SRC_FILES" ]; then
    while IFS= read -r srcfile; do
      [ -z "$srcfile" ] && continue
      is_test_exempt "$srcfile" && continue

      BASE="${srcfile%.*}"
      EXT="${srcfile##*.}"

      # Check common test file patterns
      TEST_FOUND=false
      for pattern in "${BASE}.test.${EXT}" "${BASE}.spec.${EXT}" "${BASE}_test.${EXT}" "${BASE}_test.go"; do
        if [ -f "$pattern" ] || echo "$DIFF_FILES" | grep -qF "$pattern"; then
          TEST_FOUND=true
          break
        fi
      done

      if [ "$TEST_FOUND" = false ]; then
        if $DIFF_CMD_FILE -- "$srcfile" 2>/dev/null | head -5 | grep -q '^new file\|^diff.*000000'; then
          MISSING_TESTS+=("$srcfile → missing test file (new file)")
        else
          warn "Modified $srcfile has no test file — consider adding tests"
        fi
      fi
    done <<< "$SRC_FILES"
  fi

  if [ ${#MISSING_TESTS[@]} -gt 0 ]; then
    for mt in "${MISSING_TESTS[@]}"; do
      fail "Missing test: $mt"
    done
  else
    pass "All changed code has tests (or is exempt)"
  fi
else
  pass "No files to check for tests"
fi

# ─── 7. Code quality ────────────────────────────────────────────

section "Code Quality"

# Check for console.log in changes
if echo "$DIFF_CONTENT" | grep '^+' | grep -q 'console\.log'; then
  fail "console.log found in changes — remove before commit"
else
  pass "No console.log in changes"
fi

# Check for TODO/FIXME/HACK in new code (warn, don't fail)
TODO_COUNT=$(echo "$DIFF_CONTENT" | grep '^+' | grep -ciE 'TODO|FIXME|HACK' || true)
if [ "$TODO_COUNT" -gt 0 ]; then
  warn "$TODO_COUNT TODO/FIXME/HACK comment(s) in changes"
fi

# ─── 8. Review Gate ─────────────────────────────────────────────

section "Review Gate"

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" == sprint-* ]]; then
  REVIEW_FILES=(/tmp/review-correctness.json /tmp/review-security.json /tmp/review-conventions.json)
  MISSING_REVIEWS=()
  FAILED_REVIEWS=()

  for rf in "${REVIEW_FILES[@]}"; do
    name=$(basename "$rf" .json | sed 's/review-//')
    if [ ! -f "$rf" ]; then
      MISSING_REVIEWS+=("$name")
    elif [ ! -s "$rf" ]; then
      MISSING_REVIEWS+=("$name (empty file)")
    else
      verdict=$(grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$rf" 2>/dev/null | head -1 | grep -o '"[^"]*"$' | tr -d '"')
      if [ "$verdict" = "fail" ]; then
        FAILED_REVIEWS+=("$name")
      fi
    fi
  done

  if [ ${#MISSING_REVIEWS[@]} -gt 0 ]; then
    fail "Reviews missing: ${MISSING_REVIEWS[*]} — run parallel review before commit"
  elif [ ${#FAILED_REVIEWS[@]} -gt 0 ]; then
    fail "Reviews with blockers: ${FAILED_REVIEWS[*]} — fix blockers before commit"
  else
    pass "All reviews completed and approved"
  fi
else
  pass "Review gate — not a sprint branch, skipping"
fi

# ─── Test results JSON ──────────────────────────────────────────

section "Writing test-results.json"

RESULTS_FILE=".ai/logs/test-results.json"
mkdir -p .ai/logs

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
VERDICT="pass"
if [ ${#ERRORS[@]} -gt 0 ]; then
  VERDICT="fail"
fi

# Build JSON arrays
ERRORS_JSON="["
for i in "${!ERRORS[@]}"; do
  [ "$i" -gt 0 ] && ERRORS_JSON+=","
  ESCAPED=$(echo "${ERRORS[$i]}" | sed 's/"/\\"/g')
  ERRORS_JSON+="\"$ESCAPED\""
done
ERRORS_JSON+="]"

WARNINGS_JSON="["
for i in "${!WARNINGS[@]}"; do
  [ "$i" -gt 0 ] && WARNINGS_JSON+=","
  ESCAPED=$(echo "${WARNINGS[$i]}" | sed 's/"/\\"/g')
  WARNINGS_JSON+="\"$ESCAPED\""
done
WARNINGS_JSON+="]"

MISSING_JSON="["
if [ ${#MISSING_TESTS[@]} -gt 0 ]; then
  for i in "${!MISSING_TESTS[@]}"; do
    [ "$i" -gt 0 ] && MISSING_JSON+=","
    ESCAPED=$(echo "${MISSING_TESTS[$i]}" | sed 's/"/\\"/g')
    MISSING_JSON+="\"$ESCAPED\""
  done
fi
MISSING_JSON+="]"

cat > "$RESULTS_FILE" << ENDJSON
{
  "timestamp": "$TIMESTAMP",
  "verdict": "$VERDICT",
  "mode": "$MODE",
  "missing_tests": $MISSING_JSON,
  "errors": $ERRORS_JSON,
  "warnings": $WARNINGS_JSON,
  "counts": {
    "errors": ${#ERRORS[@]},
    "warnings": ${#WARNINGS[@]},
    "missing_tests": ${#MISSING_TESTS[@]}
  }
}
ENDJSON

pass "test-results.json written to $RESULTS_FILE"

# ─── Summary ─────────────────────────────────────────────────────

section "Summary"

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo ""
  echo "Warnings (${#WARNINGS[@]}):"
  for w in "${WARNINGS[@]}"; do
    echo "  ⚠ $w"
  done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "ERRORS (${#ERRORS[@]}):"
  for e in "${ERRORS[@]}"; do
    echo "  ✗ $e"
  done
  echo ""
  echo "VERIFY FAILED — fix errors above before proceeding to review."
  exit 1
else
  echo ""
  echo "VERIFY PASSED ✓"
  echo "Warnings: ${#WARNINGS[@]}, Errors: 0"
  exit 0
fi
