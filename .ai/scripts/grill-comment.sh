#!/usr/bin/env bash
# grill-comment.sh <issue-nr> <body-file>
#
# Posts a grill decision comment on an issue in THIS repo. It is the ONLY way
# `.ai/skills/grill.md` may write to the issue tracker.
#
# ── TODO when adopting this template ────────────────────────────────────────
# Set EXPECTED_SLUG below to your own `host/owner/repo`. The constant is the
# whole point of the script — see the comment at that line.
#
# ── Why the script exists ───────────────────────────────────────────────────
# Seven review rounds tried to solve the same problem with prose in the skill
# file: "don't use `gh issue edit --body-file`", then "nor `-b`/`--title`/
# `gh api PATCH`", then "nor `-R`/URL arguments/`gh api POST`/`--hostname`".
# Each round banned a SPELLING; the next round found a new spelling of the same
# capability. A rule the agent itself must interpret and obey is precisely the
# failure class this workflow core fights: a control that cannot fire looks like
# a control that passed.
#
# The fix is not a better-worded rule but a narrower interface. The skill's rule
# is now one line — "call `gh` only via this script" — and the script HAS NO
# code path to the issue body, the title, other repos or other hosts. There is
# nothing to spell wrong.
#
# ── Threat model: what the script IS and is not ─────────────────────────────
#
# The script is a NARROW INTERFACE, not a sandbox.
#
# It protects against a capability being used BY ACCIDENT (there is no code path
# to the body, the title, another repo or another host) and against AMBIENT or
# stale gh configuration (the environment is built with an allowlist and gh's
# config directory is pinned).
#
# It does NOT protect against a caller who controls the environment. `PATH` must
# pass through for gh to be found, so a trojan `gh` first in PATH gets both argv
# and the token; `BASH_ENV` gives code execution in this shell already. There is
# no patch for that: whoever can set them can just as well run `gh issue edit`
# alongside the script. Established under review, 2026-08-13, and deliberately
# left open.
#
# It also does NOT protect against someone EDITING the script. Source-text checks
# in a test suite (pins, allowlists, counters) are regression detectors that catch
# mistakes and make deliberate changes visible in review — not a boundary: whoever
# changes this file can change the test suite in the same commit.
#
# So never rewrite the lines below as "cannot" when they mean "there is no code
# path to". A false "this is enforced mechanically" is worse than an honest "this
# is a rule" — the next reader stops being careful.
#
# ── What the script does, point by point ────────────────────────────────────
#   · Writes comments only. Never the body, the title, labels or new issues.
#   · Writes only to EXPECTED_SLUG, host included. The slug is derived from the
#     git remote and compared against the constant — if it does not match, the
#     script dies. The environment is built with an allowlist (`env -i`), not by
#     enumerating dangerous variables.
#     The host prefix in -R pins the HOST CHOICE: without it, `-R owner/repo`
#     would let gh pick the host from its configuration. It does NOT pin the
#     transport — see the next point.
#   · Pins gh's configuration instead of passing through the variables that point
#     at it. `config.yml` supports `http_unix_socket`, which redirects EVERY call
#     to a unix socket regardless of what -R says — and the file's location is
#     determined by HOME/APPDATA/USERPROFILE. Passing those through would have
#     been the same capability as GH_HOST, just spelled differently. The script
#     instead sets GH_CONFIG_DIR to an empty directory it owns, and passes the
#     token via stdin; none of the three variables reach gh.
#   · Refuses an unstamped decision file. Without `Issue: #<nr>` matching the
#     argument, a date, and the human-confirmed marker, it cannot be told apart
#     from a leftover file for another issue.
#   · Checks the file's STAMP, never its BODY. Everything below the stamp goes
#     verbatim to the tracker — the script does not read it, does not filter it
#     and does not know what it contains. The only thing guarding the content is
#     the prose rule in `grill.md` step 4 ("do not include free-text answers
#     verbatim; they can carry hostnames or key material") — a rule, not a
#     mechanism. That is a deliberate choice, not a forgotten gap: a token-shaped
#     regex would be exactly the spelling enumeration this whole script replaced.
#
# Exit: 0 posted · 1 validation error · 2 environment error (no remote, no gh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

die() { echo "ERROR: $1" >&2; exit "${2:-1}"; }

# ─── Arguments ───────────────────────────────────────────────────────────────

[ "$#" -eq 2 ] || die "Usage: grill-comment.sh <issue-nr> <body-file>"

ISSUE_NR="$1"
BODY_FILE="$2"

# Digits only. An issue number that is a flag (`--body`) or a URL would be a way
# to redirect the call — gh takes both a number and a URL positionally.
case "$ISSUE_NR" in
  ''|*[!0-9]*) die "Issue number '$ISSUE_NR' is not a positive integer" ;;
  0*)          die "Issue number '$ISSUE_NR' has a leading zero" ;;
esac

# A flag-shaped path is rejected BEFORE any file operation. `head -n 10 -v` reads
# stdin instead of the file, while `--body-file -v` treats the same string as a
# filename — the thing checked and the thing sent would then differ. Verified
# empirically under review, 2026-08-13. The `--` further down is suspenders; this
# guard is the belt.
#
# Since the token travels via stdin (see RUN below), the guard also carries the
# TOKEN'S CONFIDENTIALITY: `--body-file -` means "read the body from stdin", and
# stdin is now the token. Without the guard, the path `-` would have posted our
# own token as an issue comment. Both `-` and `-v` are covered by this pattern.
case "$BODY_FILE" in
  -*) die "Decision file path '$BODY_FILE' starts with '-' and could be read as a flag" ;;
esac

[ -f "$BODY_FILE" ] || die "No decision file found: $BODY_FILE"
[ -s "$BODY_FILE" ] || die "Decision file is empty: $BODY_FILE"

# ─── Stamp check ─────────────────────────────────────────────────────────────
#
# The stamp is the only thing separating a fresh decision file from a leftover.
# `.context/` is gitignored, unversioned and shared with other skills, so the
# path itself proves nothing about the content.

STAMP_ZONE="$(head -n 10 -- "$BODY_FILE")"

printf '%s' "$STAMP_ZONE" | grep -qE "^Issue: #${ISSUE_NR}([^0-9]|$)" \
  || die "Decision file lacks the line 'Issue: #${ISSUE_NR}' in its first ten lines — it does not belong to this issue, or is unstamped"

printf '%s' "$STAMP_ZONE" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
  || die "Decision file lacks a date (YYYY-MM-DD) in the stamp — fresh cannot be told from leftover"

# The marker is a FRESHNESS SIGNAL, not an attestation.
#
# It checks a string the agent writes itself, so it cannot possibly distinguish a
# human-confirmed decision from an invented one — the same flaw that removed the
# round counter from grill.md. What it does buy: it makes it impossible to post an
# arbitrary file as a decision BY ACCIDENT, because the file has to be written for
# the purpose. Never describe it as more than that.
printf '%s' "$STAMP_ZONE" | grep -qi 'human-confirmed' \
  || die "Decision file lacks the 'human-confirmed' marker in the stamp — it does not look like a grill decision file"

# ─── Destination ─────────────────────────────────────────────────────────────
#
# Derived from the git remote, never from the environment. Supported forms:
#   https://host/owner/repo(.git)   ssh://git@host/owner/repo(.git)   git@host:owner/repo(.git)

REMOTE_URL="$(git remote get-url origin 2>/dev/null)" || REMOTE_URL=""
[ -n "$REMOTE_URL" ] || die "Repo has no 'origin' remote — the destination cannot be derived, and guessing would be the wrong kind of helpfulness" 2

parse_slug() {
  local url="$1" rest host path
  rest="${url%.git}"
  case "$rest" in
    *://*)   rest="${rest#*://}"; rest="${rest#*@}"; host="${rest%%/*}"; path="${rest#*/}" ;;
    *@*:*)   rest="${rest#*@}";   host="${rest%%:*}"; path="${rest#*:}" ;;
    *)       return 1 ;;
  esac
  case "$host" in ''|*/*) return 1 ;; esac
  # Exactly owner/repo — no fewer and no more segments.
  case "$path" in
    */*/*|*/) return 1 ;;
    */*)      : ;;
    *)        return 1 ;;
  esac
  [ -n "${path%%/*}" ] && [ -n "${path#*/}" ] || return 1
  # ALWAYS host/owner/repo — never the host-less form. `-R owner/repo` lets gh
  # pick the host from its configuration, so without the host prefix the HOST
  # CHOICE would be ambient even with EXPECTED_SLUG set.
  #
  # The host prefix closes the host choice, but not the TRANSPORT: `config.yml`
  # can redirect the call via `http_unix_socket` regardless of what -R says. That
  # gap is closed further down by pinning gh's config directory — not here.
  printf '%s/%s' "$host" "$path"
}

REPO_SLUG="$(parse_slug "$REMOTE_URL")" \
  || die "Cannot parse origin remote '$REMOTE_URL' into owner/repo — refusing to post rather than guess the destination" 2

# Deriving from the git remote pins nothing: `git remote set-url origin …`, or a
# copy of this script in another repo, moves the destination without a single line
# here changing. Verified empirically under review, 2026-08-13. The expected slug
# is therefore a CONSTANT — if the repo moves, this line must be changed under
# review.
EXPECTED_SLUG="github.com/TODO-owner/TODO-repo"
[ "$REPO_SLUG" = "$EXPECTED_SLUG" ] \
  || die "origin points at '$REPO_SLUG', not '$EXPECTED_SLUG'. The script only posts to the repo it belongs to." 2

command -v gh >/dev/null 2>&1 || die "gh is not in PATH" 2

# ─── Post ────────────────────────────────────────────────────────────────────

# gh's configuration is PINNED — it is not passed through.
#
# HOME/APPDATA/USERPROFILE used to be in the allowlist, justified with "otherwise
# gh cannot find its credentials". But those are exactly the variables that locate
# gh's `config.yml`, and that file supports the key `http_unix_socket` (visible in
# `gh config list`). GH_REPO/GH_HOST/GH_CONFIG_DIR/XDG_CONFIG_HOME were closed
# while APPDATA was the same capability spelled differently.
#
# Verified empirically 2026-08-13 (Windows 11, git-bash/MINGW64, gh 2.80.0): with
# APPDATA pointed at a directory holding its own `GitHub CLI/config.yml`,
# `gh issue list -R github.com/<owner>/<repo>` went to `dial unix C:/…/pwned.sock`
# — with -R untouched, using the token gh found in the same poisoned directory.
# APPDATA beats HOME on Windows.
#
# The countermeasure: an EMPTY directory the script creates itself becomes
# GH_CONFIG_DIR. An empty directory has no `config.yml` to poison, and
# GH_CONFIG_DIR beats APPDATA (verified the same day: the same call with both a
# poisoned APPDATA and a pinned GH_CONFIG_DIR went to https://api.github.com).
# Credentials arrive via GH_TOKEN instead — see the token lookup below.
GH_CONF_DIR="$(mktemp -d)" || die "cannot create a temporary gh config directory" 2
cleanup() { rm -rf "$GH_CONF_DIR"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# ONE argv array, built once. Dry-run prints exactly that array; the real run
# executes exactly that array. Previously each branch had its own copy — dry-run a
# hand-written printf — and the test then checked the printf, not the call.
# Mutation testing confirmed the hole: changing the real call to
# -R "${GH_REPO:-$REPO_SLUG}" still gave an all-green suite (2026-08-13). Two
# copies of a command means the test reviews the copy that does not run.
#
# `env -i` is an ALLOWLIST, not `env -u`'s denylist. Enumerating dangerous names is
# the failure pattern from the seven rounds; here only what gh actually needs
# passes: PATH (to find env/bash/gh) and the pinned config directory. Verified
# 2026-08-13 that nothing more is needed on Windows: the same environment reached
# api.github.com without HOME, APPDATA or USERPROFILE.
#
# Be honest about what `env -i` gives: on Windows/git-bash the resulting
# environment is not empty. The MSYS2 runtime and bash put back MSYSTEM,
# SYSTEMROOT, WINDIR, PWD, SHLVL and `_` (observed 2026-08-13 by logging `env` in
# the process the array starts). None of them locate gh's configuration, so they
# do not change the conclusion — but "env -i gives an empty environment" would be
# wrong to write.
#
# The token shim: the token must NEVER be in argv, because argv is visible in the
# process list. The inner shell reads it from stdin and exports it, so it reaches
# gh as an environment variable — readable only by the same user. `read -r`
# without clearing IFS is enough: a token contains no whitespace, and trimming it
# is desirable. `|| exit 2` makes the assumption explicit: if the shim gets no
# line on stdin it must abort, not continue with an empty token.
RUN=(env -i
  PATH="$PATH"
  GH_CONFIG_DIR="$GH_CONF_DIR"
  bash -c 'export GH_TOKEN; read -r GH_TOKEN || exit 2; exec "$@"' grill-comment
  gh issue comment "$ISSUE_NR" -R "$REPO_SLUG" --body-file "$BODY_FILE")

if [ -n "${GRILL_COMMENT_DRY_RUN:-}" ]; then
  # Iterates the SAME array that runs for real — no second construction that can
  # diverge. Environment values are masked: they are machine-local (PATH may even
  # contain newlines), while what should be reviewed is which NAMES pass through
  # and exactly which gh arguments are built. Masking makes the output comparable
  # against an exact expected string in a test, which is the only thing that
  # catches an ADDITION — e.g. a second `--repo` that the CLI parser lets win.
  #
  # The masking is also why the printout is not sufficient as the only check: a
  # token's VALUE can become environment-controlled without the printout changing.
  #
  # Dry-run never fetches a token — the branch exits before the lookup, so there
  # is no token to print by accident.
  printf 'DRY-RUN:'
  for _tok in "${RUN[@]}"; do
    case "$_tok" in
      [A-Z_]*=*) printf ' %s=<value>' "${_tok%%=*}" ;;
      *)         printf ' %s' "$_tok" ;;
    esac
  done
  printf '\n'
  exit 0
fi

# The token is fetched in the NORMAL environment and therefore reads a possibly
# poisoned config. That is acceptable: `gh auth token` makes no network call, so
# the outcome of a poisoned config is the WRONG token — not a leaked real one.
# Verified empirically 2026-08-13 with gh 2.80.0: `gh auth token` with a poisoned
# APPDATA returned the token sitting in the poisoned directory and sent nothing
# anywhere. The conclusion is version-bound — `gh auth token` could start
# validating over the network in a later version.
#
# --hostname is derived from the pinned constant, not from the environment, so the
# token belongs to the same host -R points at.
#
# Works in both modes: locally `gh auth token` reads gh's config file, and in CI —
# where gh authenticates with GH_TOKEN in the environment rather than a config
# file — it returns that environment token.
GH_HOST_PIN="${EXPECTED_SLUG%%/*}"
GH_TOKEN_VALUE="$(gh auth token --hostname "$GH_HOST_PIN" 2>/dev/null)" || GH_TOKEN_VALUE=""
[ -n "$GH_TOKEN_VALUE" ] \
  || die "gh has no token for $GH_HOST_PIN — run 'gh auth login' first" 2

# The token travels via stdin (never argv) and is never named in an error message.
printf '%s\n' "$GH_TOKEN_VALUE" | "${RUN[@]}"
