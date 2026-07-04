#!/usr/bin/env bash
# ready.sh — list open issues without open dependencies
#
# Usage: bash .ai/scripts/ready.sh [--help] [--json]
#
# Inspired by Beads `bd ready`. Dependencies are extracted from:
#   - GitHub task-lists (- [ ] #123)
#   - "## Dependencies" / "## Depends on" / "## Blocked by" sections
# Known limitation: false positives if #N is mentioned in code blocks or other context.
# Requires: gh CLI, jq.
#
# TODO: Set REPO below to your "<owner>/<repo>" or remove the assignment to use
# the current directory's gh remote.

set -euo pipefail

REPO="TODO/REPO"

# --- Help text ------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: bash .ai/scripts/ready.sh [--help] [--json]

Lists open GitHub issues grouped by:
  READY   — no open dependencies (can be started now)
  BLOCKED — at least one dependency that is still open

Flags:
  --help   Show this help text and exit
  --json   Machine-readable output (JSON array of {number,title,labels,blocked_by})

Repo: $REPO
Requires: gh CLI (https://cli.github.com), jq
EOF
}

# --- Argument parsing ----------------------------------------------------------

JSON_MODE=false
for arg in "$@"; do
  case "$arg" in
    --help) usage; exit 0 ;;
    --json) JSON_MODE=true ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
  esac
done

# --- Dependency checks ----------------------------------------------------------

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found." >&2
  echo "Install with: brew install gh  or  https://cli.github.com" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found." >&2
  echo "Install with: brew install jq  or  apt-get install jq" >&2
  exit 1
fi

# --- Fetch all open issues ------------------------------------------------------

issues_json=$(gh issue list \
  --repo "$REPO" \
  --json number,title,body,state,labels \
  --state open \
  --limit 200 2>&1) || {
  echo "Error: Could not fetch issues from GitHub." >&2
  echo "Verify you are authenticated (gh auth status) and have network access." >&2
  exit 1
}

# Validate the response is JSON
if ! echo "$issues_json" | jq empty 2>/dev/null; then
  echo "Error: Unexpected response from gh CLI." >&2
  echo "$issues_json" >&2
  exit 1
fi

# Build a list of all open issue numbers (for fast lookup)
open_numbers=$(echo "$issues_json" | jq -r '.[].number')

# Convert to a key-value string for grep: "|123|456|789|"
open_lookup="|$(echo "$open_numbers" | tr '\n' '|')"

# --- Extract dependencies per issue ---------------------------------------------

# For each issue: parse task-lists and dependency sections, return open deps.
#
# Strategy:
#   1. Task-list pattern: "- [ ] #N" (checkbox referring to an issue)
#   2. Section pattern: find a section with "Dependencies"/"Depends on"/"Blocked by",
#      then collect all "#N" occurrences until the next "##" heading.

extract_open_deps() {
  local body="$1"
  local found_deps=""

  # --- Source 1: GitHub task-lists ----------------------------------------------
  # Match "- [ ] #N" (open checkbox that is an issue reference)
  while IFS= read -r line; do
    if [[ "$line" =~ ^\-\ \[\ \]\ \#([0-9]+) ]]; then
      local num="${BASH_REMATCH[1]}"
      if echo "$open_lookup" | grep -q "|${num}|"; then
        found_deps="$found_deps $num"
      fi
    fi
  done <<< "$body"

  # --- Source 2: Dependency sections --------------------------------------------
  # Activate collection when we see a matching heading, end at next "##" heading.
  local in_dep_section=false
  while IFS= read -r line; do
    # Check if we are in a dependency section
    if [[ "$line" =~ ^##[[:space:]]+(Dependencies|Depends\ on|Blocked\ by) ]]; then
      in_dep_section=true
      continue
    fi
    # New heading ends the section
    if [[ "$line" =~ ^## ]]; then
      in_dep_section=false
      continue
    fi
    # Collect issue numbers from the section
    if $in_dep_section; then
      # Find all #N occurrences on the line
      local tmp="$line"
      while [[ "$tmp" =~ \#([0-9]+) ]]; do
        local num="${BASH_REMATCH[1]}"
        if echo "$open_lookup" | grep -q "|${num}|"; then
          found_deps="$found_deps $num"
        fi
        # Strip matched number to avoid infinite loop
        tmp="${tmp#*#${num}}"
      done
    fi
  done <<< "$body"

  # Deduplicate and return
  echo "$found_deps" | tr ' ' '\n' | sort -un | tr '\n' ' ' | xargs
}

# --- Label priority -------------------------------------------------------------

label_priority() {
  local labels="$1"
  # Returns a sort number: lower = higher priority
  case "$labels" in
    *security*)   echo 1 ;;
    *tech-debt*)  echo 2 ;;
    *enhancement*)echo 3 ;;
    *bug*)        echo 4 ;;
    *)            echo 5 ;;
  esac
}

first_label() {
  local labels_json="$1"
  # Returns the label with highest priority (lowest sort number)
  local best_label="other"
  local best_prio=99
  while IFS= read -r lbl; do
    local prio
    prio=$(label_priority "$lbl")
    if (( prio < best_prio )); then
      best_prio=$prio
      best_label="$lbl"
    fi
  done <<< "$(echo "$labels_json" | jq -r '.[].name' 2>/dev/null || echo '')"
  echo "$best_label"
}

# --- Classify issues ------------------------------------------------------------

declare -a ready_issues=()
declare -a blocked_issues=()

# Temp files for JSON mode
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

issue_count=$(echo "$issues_json" | jq 'length')

for i in $(seq 0 $((issue_count - 1))); do
  number=$(echo "$issues_json" | jq -r ".[$i].number")
  title=$(echo "$issues_json" | jq -r ".[$i].title")
  body=$(echo "$issues_json" | jq -r ".[$i].body // \"\"")
  labels_json=$(echo "$issues_json" | jq -c ".[$i].labels")

  open_deps=$(extract_open_deps "$body")
  dep_count=$(echo "$open_deps" | wc -w | tr -d ' ')
  label=$(first_label "$labels_json")
  prio=$(label_priority "$label")

  if [[ -z "$open_deps" ]]; then
    # READY: no open deps
    ready_issues+=("${prio}|${label}|${number}|${title}|${dep_count}")
    if $JSON_MODE; then
      echo "$issues_json" | jq ".[$i] + {blocked_by: [], status: \"ready\"}" >> "$tmpfile"
    fi
  else
    # BLOCKED: at least one open dep
    dep_list=$(echo "$open_deps" | tr ' ' ',')
    blocked_issues+=("${number}|${title}|${dep_list}")
    if $JSON_MODE; then
      dep_array=$(echo "$open_deps" | tr ' ' '\n' | jq -R . | jq -s .)
      echo "$issues_json" | jq ".[$i] + {blocked_by: $dep_array, status: \"blocked\"}" >> "$tmpfile"
    fi
  fi
done

# --- JSON output ----------------------------------------------------------------

if $JSON_MODE; then
  # Collect all rows into an array
  jq -s '.' "$tmpfile"
  exit 0
fi

# --- Human-readable output ------------------------------------------------------

# Sort READY by priority (column 1)
IFS=$'\n' sorted_ready=($(printf '%s\n' "${ready_issues[@]}" | sort -t'|' -k1,1n -k2,2 -k3,3n))
unset IFS

ready_count=${#sorted_ready[@]}
blocked_count=${#blocked_issues[@]}

echo "READY ($ready_count):"
if (( ready_count == 0 )); then
  echo "  (no issues without open dependencies)"
else
  for entry in "${sorted_ready[@]}"; do
    IFS='|' read -r _prio label number title dep_count <<< "$entry"
    printf "  [%-12s] #%-4s %s (deps: %s)\n" "$label" "$number" "$title" "$dep_count"
  done
fi

echo ""
echo "BLOCKED ($blocked_count):"
if (( blocked_count == 0 )); then
  echo "  (no blocked issues)"
else
  for entry in "${blocked_issues[@]}"; do
    IFS='|' read -r number title dep_list <<< "$entry"
    dep_display=$(echo "$dep_list" | tr ',' ' ' | sed 's/ *$//' | tr ' ' '\n' | sed 's/^/#/' | tr '\n' ' ' | sed 's/ $//')
    printf "  #%-4s %s — waiting on: %s\n" "$number" "$title" "$dep_display"
  done
fi
