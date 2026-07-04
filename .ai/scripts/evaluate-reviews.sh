#!/usr/bin/env bash
# evaluate-reviews.sh — Parse review JSON files and determine if blockers exist
# Exit code 0 = no blockers, 1 = blockers found

set -euo pipefail

REVIEW_DIR="${1:-/tmp}"
REVIEW_PREFIX="review-"
HAS_BLOCKERS=false
TOTAL_BLOCKERS=0
TOTAL_WARNINGS=0
TOTAL_NITS=0

echo "── Review Evaluation ──"
echo ""

# Verify at least one review file exists
SHOPT=$(shopt -p nullglob 2>/dev/null || true)
shopt -s nullglob
REVIEW_GLOB=("${REVIEW_DIR}/${REVIEW_PREFIX}"*.json)
eval "$SHOPT"
if [ ${#REVIEW_GLOB[@]} -eq 0 ]; then
  echo "ERROR: No review files found in $REVIEW_DIR (looking for ${REVIEW_PREFIX}*.json)"
  exit 2
fi

for review_file in "${REVIEW_GLOB[@]}"; do
  [ ! -f "$review_file" ] && continue

  name=$(basename "$review_file" .json | sed "s/${REVIEW_PREFIX}//")

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

    # Show blocker details
    jq -r '.blockers[] | "    BLOCKER: \(.file):\(.line // "?") — \(.description)"' "$review_file" 2>/dev/null || true
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
