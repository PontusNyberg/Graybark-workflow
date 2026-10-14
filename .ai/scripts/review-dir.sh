#!/usr/bin/env bash
# review-dir.sh — where a review round's artifacts live, and how a review skip
# is validated. Sourceable library + CLI (`bash .ai/scripts/review-dir.sh`
# prints the resolved directory).
#
# Two functions, both with exactly one implementation on purpose:
#
#   review_resolve_dir [explicit-dir]   → prints the artifact directory
#   review_skip_check   <dir>           → validates the skip request/approval pair
#
# Every caller (the orchestrator in implement-issue Step 8, evaluate-reviews.sh,
# and a project's verify.sh review gate if it has one) MUST use these rather than
# compute the path or the validation again. A second copy that drifts means the
# gate writes in one directory and the evaluation reads in another — i.e. silent
# green.
#
# ── Precedence ──────────────────────────────────────────────────────────────
#
#     explicit argument  >  $REVIEW_DIR  >  per-branch default
#
# The per-branch default is <repo-root>/.ai/logs/reviews/<branch-slug>/. In a git
# worktree, <repo-root> is that worktree's own root, so two parallel sessions get
# separate directories even on the same branch name. <branch-slug> is the branch
# name with everything outside [A-Za-z0-9._-] replaced by `-` (so `fix/429-x` →
# `fix-429-x`); a detached HEAD gives `detached-<short-sha>`. `.ai/logs/` is
# gitignored.
#
# The default used to be `/tmp`. That is a global directory: on 2026-08-08 three
# parallel sessions shared it, a review context file vanished mid-round, and
# another session later overwrote three `review-*.json` with verdicts about
# entirely different files. Artifacts from before this change are simply ignored,
# never deleted — they may belong to another session.
#
# A RELATIVE directory (argument or $REVIEW_DIR) is resolved against the repo
# root, not against your cwd, so the answer does not depend on where you stand.

# Resolve the artifact directory. Creates it if missing.
review_resolve_dir() {
  local explicit="${1:-}" root dir branch slug sha
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$PWD"

  dir="$explicit"
  [ -n "$dir" ] || dir="${REVIEW_DIR:-}"

  if [ -z "$dir" ]; then
    branch="$(git branch --show-current 2>/dev/null || echo "")"
    if [ -n "$branch" ]; then
      slug="$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '-')"
    else
      sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
      slug="detached-$sha"
    fi
    dir="$root/.ai/logs/reviews/$slug"
  fi

  case "$dir" in
    /*|[A-Za-z]:[/\\]*) : ;;        # already absolute (POSIX or Windows drive)
    *) dir="$root/$dir" ;;
  esac

  mkdir -p "$dir" || return 1
  printf '%s' "$dir"
}

# Validate the skip pair in <dir>.
#
# Exit codes are a CONTRACT — callers branch on them:
#   0 = an approved skip applies (message on stdout explains it)
#   1 = no skip applies (no request, or verdict=denied). A denial is a NORMAL
#       outcome: run the reviewers as if no skip had been requested. Never
#       escalate a denial to the user.
#   2 = the artifacts are INCONSISTENT (hash mismatch, wrong branch/head_sha,
#       unknown verdict, empty approver/rationale, approval without request).
#       That is an artifact problem, not a review finding — it cannot be solved
#       by running reviewers. Start the round over.
#
# The empty-reason and empty-approver bypasses are closed deliberately: those
# fields are the only audit trail saying who authorized skipping all code review,
# so an empty one is a hard fail rather than a pass.
review_skip_check() {
  local dir="${1:-}" req="" app="" branch head
  req="$dir/review-skip-request.json"
  app="$dir/review-skip-approval.json"

  if [ ! -f "$req" ]; then
    if [ -f "$app" ]; then
      echo "Skip approval present without a request in $dir — inconsistent pair."
      return 2
    fi
    return 1
  fi

  if [ ! -f "$app" ]; then
    echo "Skip requested but not approved (no review-skip-approval.json) — reviewers are required."
    return 1
  fi

  command -v jq >/dev/null 2>&1 || { echo "jq is required to validate a review skip."; return 2; }

  local r_branch r_head r_reason r_hash a_branch a_head a_hash verdict approver rationale calc
  r_branch=$(jq -r '.branch // ""' "$req")
  r_head=$(jq -r '.head_sha // ""' "$req")
  r_reason=$(jq -r '.reason // ""' "$req")
  r_hash=$(jq -r '.reason_sha256 // ""' "$req")
  a_branch=$(jq -r '.branch // ""' "$app")
  a_head=$(jq -r '.head_sha // ""' "$app")
  a_hash=$(jq -r '.reason_sha256 // ""' "$app")
  verdict=$(jq -r '.verdict // ""' "$app")
  approver=$(jq -r '.approver // ""' "$app")
  rationale=$(jq -r '.rationale // ""' "$app")

  # An empty reason cannot be approved — it is not a description of a diff.
  if [ -z "$r_reason" ] || [ -z "$r_hash" ]; then
    echo "Skip request has an empty reason or no reason_sha256 — refusing to treat it as approvable."
    return 2
  fi

  # A multi-line reason hashes differently depending on which tool normalized the
  # line endings, so it is rejected rather than hashed.
  case "$r_reason" in
    *$'\n'*) echo "Skip reason spans multiple lines — it must be a single line."; return 2 ;;
  esac

  calc=$(printf '%s' "$r_reason" | sha256sum | cut -d' ' -f1)
  if [ "$calc" != "$r_hash" ] || [ "$a_hash" != "$r_hash" ]; then
    echo "Skip reason hash mismatch (request $r_hash, approval $a_hash, computed $calc) — the approved reason is not the reason on disk."
    return 2
  fi

  branch="$(git branch --show-current 2>/dev/null || echo "")"
  head="$(git rev-parse HEAD 2>/dev/null || echo "")"
  if [ "$a_branch" != "$r_branch" ] || [ "$a_head" != "$r_head" ]; then
    echo "Skip approval is for $a_branch@$a_head but the request is for $r_branch@$r_head — inconsistent pair."
    return 2
  fi
  if [ -n "$branch" ] && [ "$r_branch" != "$branch" ]; then
    echo "Skip pair is for branch $r_branch but HEAD is on $branch — it reviewed a different diff."
    return 2
  fi
  if [ -n "$head" ] && [ "$r_head" != "$head" ]; then
    echo "Skip pair is for commit $r_head but HEAD is $head — the diff changed after approval."
    return 2
  fi

  case "$verdict" in
    approved)
      if [ -z "$approver" ] || [ -z "$rationale" ]; then
        echo "Approved skip without approver or rationale — that is the only audit trail for skipping all code review."
        return 2
      fi
      echo "Review skipped with an approved reason: \"$r_reason\" (approved by $approver: $rationale)"
      return 0
      ;;
    denied)
      echo "Skip DENIED by ${approver:-skip-approver}: ${rationale:-no rationale given} — run the reviewers as usual."
      return 1
      ;;
    *)
      echo "Unknown skip verdict '${verdict}' — expected approved or denied."
      return 2
      ;;
  esac
}

# CLI mode: print the resolved directory. Guard so sourcing does not run it.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  review_resolve_dir "${1:-}" || exit 1
  echo
fi
