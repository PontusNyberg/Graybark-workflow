#!/usr/bin/env bash
# evaluate-reviews.sh — parse reviewer output and gate on blockers AND verdicts
#
# Exit 0 = every reviewer passed and no blockers were found — OR the reviewers
#          were skipped with an agent-approved skip (REVIEW SKIPPED)
# Exit 1 = some reviewer returned fail, or blockers were found
# Exit 2 = review files are missing without an approved skip explaining the
#          absence, are invalid, or the skip artifacts are inconsistent
#
# Usage: evaluate-reviews.sh [REVIEW_DIR]
# Requires: jq, review files as REVIEW_DIR/review-*.json
#
# Artifact directory — precedence:
#
#     explicit argument  >  $REVIEW_DIR  >  per-branch default
#
# The resolution lives in review_resolve_dir() in review-dir.sh (sourced below)
# and ONLY there — a local copy that drifts would mean the round writes in one
# directory and this script reads in another, i.e. silent green.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Anchor in the script's OWN repo. Without this cd, the directory resolution and
# `git branch --show-current` would run in the CALLER's cwd; if that is a
# different worktree of the same repo, both come from there — consistently — and
# the result is REVIEW PASSED for a round you did not mean to evaluate.
#
# Consequence to know: a RELATIVE directory (argument or $REVIEW_DIR) is resolved
# against the repo root, not against your cwd.
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

REVIEW_DIR_LIB="$SCRIPT_DIR/review-dir.sh"
if [ ! -f "$REVIEW_DIR_LIB" ]; then
  echo "ERROR: missing $REVIEW_DIR_LIB — the directory resolution and skip validation are shared with the review round and cannot be reimplemented here." >&2
  exit 2
fi
# shellcheck source=./review-dir.sh
source "$REVIEW_DIR_LIB"

# Two steps, not one: review_resolve_dir reads $REVIEW_DIR from the environment,
# and that is the same name we assign to. Resolving first makes the ordering
# dependency obvious instead of implicit.
RESOLVED_REVIEW_DIR="$(review_resolve_dir "${1:-}")"
REVIEW_DIR="$RESOLVED_REVIEW_DIR"

echo "── Review Evaluation ──"
echo "Artifact directory: $REVIEW_DIR"
echo ""

# ── Approved skip ────────────────────────────────────────────────────────────
# An approved skip means the reviewers were never dispatched, so the directory
# holds only the skip pair. Without this branch the script would report "no
# review files" with exit 2 — and the workflow's recovery for exit 2 is "start
# the round over and run the reviewers", which undoes the skip that was just
# approved.
SKIP_APPROVED=0
SKIP_MSG=$(review_skip_check "$REVIEW_DIR") && SKIP_RC=0 || SKIP_RC=$?
case "$SKIP_RC" in
  0) SKIP_APPROVED=1; echo "⚠ $SKIP_MSG"; echo "" ;;
  2) echo "ERROR: $SKIP_MSG"; exit 2 ;;
  *) [ -z "$SKIP_MSG" ] || { echo "⚠ $SKIP_MSG"; echo ""; } ;;
esac

# The control artifacts match review-*.json but are not review files. Without
# this filter they count as reviewers: the skip request has no verdict → "invalid
# JSON" → exit 2, and the approval has verdict approved/denied (never "pass") →
# counted as a failing reviewer → exit 1. The net effect was that EVERY run where
# a skip had been requested hard-failed with a misleading "re-run these
# reviewers".
SHOPT=$(shopt -p nullglob 2>/dev/null || true)
shopt -s nullglob
ALL_GLOB=("${REVIEW_DIR}/review-"*.json)
eval "$SHOPT"

REVIEW_FILES=()
for f in "${ALL_GLOB[@]}"; do
  case "$(basename "$f")" in
    review-context.json|review-skip-request.json|review-skip-approval.json) continue ;;
  esac
  REVIEW_FILES+=("$f")
done

if [ ${#REVIEW_FILES[@]} -eq 0 ]; then
  if [ "$SKIP_APPROVED" -eq 1 ]; then
    # Expected outcome, not an artifact error: the reviewers were never dispatched.
    echo "── Summary ──"
    echo "  No reviewer verdicts to evaluate — the reviewers were skipped with an"
    echo "  agent-approved skip (see the warning above)."
    echo ""
    echo "REVIEW SKIPPED"
    exit 0
  fi
  echo "ERROR: No review files found in $REVIEW_DIR (looking for review-*.json)"
  exit 2
fi

HAS_BLOCKERS=false
TOTAL_BLOCKERS=0
TOTAL_WARNINGS=0
TOTAL_NITS=0

for review_file in "${REVIEW_FILES[@]}"; do
  name=$(basename "$review_file" .json | sed 's/^review-//')

  # Empty file = reviewer failed to produce output
  if [ ! -s "$review_file" ]; then
    echo "  ✗ $name: EMPTY FILE — re-run this reviewer"
    HAS_BLOCKERS=true
    continue
  fi

  # Validate JSON
  if ! jq -e '.verdict' "$review_file" > /dev/null 2>&1; then
    echo "  ✗ $name: INVALID JSON — re-run this reviewer"
    HAS_BLOCKERS=true
    continue
  fi

  verdict=$(jq -r '.verdict' "$review_file")
  blockers=$(jq -r '.blockers | length' "$review_file" 2>/dev/null || echo 0)
  warnings=$(jq -r '.warnings | length' "$review_file" 2>/dev/null || echo 0)
  nits=$(jq -r '.nits | length' "$review_file" 2>/dev/null || echo 0)

  TOTAL_BLOCKERS=$((TOTAL_BLOCKERS + blockers))
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + warnings))
  TOTAL_NITS=$((TOTAL_NITS + nits))

  if [ "$verdict" = "fail" ]; then
    echo "  ✗ $name: FAIL ($blockers blockers, $warnings warnings, $nits nits)"
    HAS_BLOCKERS=true

    # Show blocker details, including the failure scenario when the reviewer
    # supplied one — the scenario is what makes a blocker actionable.
    jq -r '.blockers[] | "    BLOCKER: \(.file):\(.line // "?") — \(.description)"
                         + (if (.failure_scenario // "") != "" then "\n      scenario: \(.failure_scenario)" else "" end)
                         + (if (.fix // "") != "" then "\n      fix: \(.fix)" else "" end)' \
      "$review_file" 2>/dev/null || true
  else
    echo "  ✓ $name: PASS ($warnings warnings, $nits nits)"
  fi
done

echo ""
echo "── Summary ──"
echo "  Blockers: $TOTAL_BLOCKERS"
echo "  Warnings: $TOTAL_WARNINGS"
echo "  Nits: $TOTAL_NITS"

if [ "$HAS_BLOCKERS" = true ]; then
  echo ""
  echo "REVIEW FAILED — fix blockers before proceeding."
  exit 1
else
  echo ""
  echo "REVIEW PASSED ✓"
  exit 0
fi
