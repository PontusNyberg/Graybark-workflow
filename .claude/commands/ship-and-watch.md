---
description: Push branch, open (or reuse) PR, request Copilot review, and loop to address Copilot comments until silent.
---

# /ship-and-watch

Ships the current branch and runs the AI code review gate (GitHub Copilot) as a self-driving loop.

This command exists to automate the external AI review feedback loop. In a sister
project, one incident PR went through 9 Copilot review batches because a human had
to manually shepherd each round. This command replaces that manual shepherding.
The empirical GitHub notes below were verified in that sister project (PR #137
2026-05-19, PR #150 2026-06-02); the bot ID is a GitHub-global constant.

**Use this command AFTER:**
- Specialist work is merged into the feature branch
- `bash .ai/scripts/verify.sh` has passed

**Ordering relative to internal reviewers — both work; pick one per project:**
- **PR before internal reviewers** (between Step 7 and Step 8 of `implement-issue.md`):
  let Copilot comment first, address its findings, THEN run internal reviewers on the
  settled diff. Avoids internal reviewers wasting context on a diff Copilot has already flagged.
- **PR after internal reviewers** (after Step 10): internal reviewers gate the commit,
  then /ship-and-watch runs Copilot as the final external gate before merge.

**Do NOT use this command for:**
- The default branch (`git branch --show-current` returns `master`/`main`) — abort.
- Branches with uncommitted changes — commit or stash first.
- Throwaway/experimental branches you don't intend to merge.

**Note on temp files:** all loop state lives in `.ai/logs/` (gitignored) rather than
`/tmp/` — this survives across ticks and works on Windows (Git Bash) where `/tmp/`
is process-local and unreliable.

---

## Steps

### 1. Sanity checks

```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "master" ] || [ "$CURRENT_BRANCH" = "main" ]; then
  echo "ABORT: on the default branch. Create a feature branch first."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "ABORT: uncommitted changes. Commit or stash first."
  exit 1
fi
```

### 2. Run pre-push checks

```bash
bash .ai/scripts/verify.sh
```

If verify fails — STOP. Do not push. Fix the errors and re-run `/ship-and-watch`.

### 3. Push and open (or reuse) PR

```bash
git push -u origin "$CURRENT_BRANCH"
```

If a PR already exists for this branch — reuse it. Otherwise create one. The invoking
agent (or human) MUST supply the title and body — there is no automated extraction.
Source the content from the iteration log if one exists (`.ai/logs/<issue-nr>.md`),
or compose it from the issue and the latest commit(s). The block below is a template,
not literal commands — substitute real values before running:

```bash
if ! gh pr view --json number -q .number 2>/dev/null; then
  gh pr create --title "<short title>" --body "$(cat <<'PRBODY'
## Summary
- <one to three bullets>

## Test plan
- [x] verify.sh passed locally
- [ ] Copilot review (auto-requested via /ship-and-watch)
- [ ] Internal reviewers (correctness/security/conventions/lifecycle)

Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
fi
```

Capture the PR number:

```bash
PR_NR=$(gh pr view --json number -q .number)
echo "$PR_NR" > .ai/logs/current-pr.txt
```

### 4. Request Copilot review (first time)

GitHub Copilot auto-review via repo ruleset is unavailable on free private
repos (requires GitHub Team). We trigger it via the GitHub API.

**Record the cutoff timestamp BEFORE triggering** — otherwise Copilot can
post comments in the gap between trigger and cutoff write, and those
comments get filtered out on the first polling tick:

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" > .ai/logs/copilot-cutoff.txt

OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# GraphQL is the reliable trigger for BOTH first review and re-reviews.
PR_ID=$(gh api graphql -f query="query{repository(owner:\"${OWNER_REPO%%/*}\",name:\"${OWNER_REPO##*/}\"){pullRequest(number:$PR_NR){id}}}" --jq '.data.repository.pullRequest.id')
gh api graphql -f query="mutation{requestReviews(input:{pullRequestId:\"$PR_ID\",botIds:[\"BOT_kgDOCnlnWA\"],union:true}){pullRequest{number}}}"

# Confirm Copilot attached; if empty, the trigger did not land.
gh api "repos/$OWNER_REPO/pulls/$PR_NR/requested_reviewers" --jq '.users[].login'
# Expected output: Copilot
```

**Important — exact bot name:** The reviewer login is `Copilot` (capital C).
- `gh pr edit --add-reviewer Copilot` → fails (gh CLI quirk — cannot resolve the bot user)
- `gh pr edit --add-reviewer copilot-pull-request-reviewer` → fails
- `gh pr comment "@copilot review"` → posts but does not trigger the bot
- `gh api ... -f "reviewers[]=Copilot"` (REST) → **unreliable even for the first
  review** — verified empirically in a sister project on PR #150 (2026-06-02): the
  REST POST was a no-op (returned `requested_reviewers: []`). Prefer the GraphQL
  `requestReviews` path for the first review too.

**Re-triggering after Copilot has already reviewed:** The REST endpoint
is a no-op when the reviewer has already submitted a review (it silently
succeeds but no new review is queued). Use the GraphQL `requestReviews`
mutation with `botIds` and `union: true`:

```bash
PR_ID=$(gh api graphql -f query="query{repository(owner:\"${OWNER_REPO%%/*}\",name:\"${OWNER_REPO##*/}\"){pullRequest(number:$PR_NR){id}}}" --jq '.data.repository.pullRequest.id')
COPILOT_BOT_ID="BOT_kgDOCnlnWA"  # GitHub-wide constant for the copilot-pull-request-reviewer app

gh api graphql -f query="mutation{requestReviews(input:{pullRequestId:\"$PR_ID\",botIds:[\"$COPILOT_BOT_ID\"],union:true}){pullRequest{number}}}"
```

(Verified empirically in a sister project on PR #137, 2026-05-19: REST POST after
a prior review silently does nothing; GraphQL `botIds` re-queues the request and
Copilot reviews the new HEAD.)

### 5. Enter the polling loop

**Reset the silent-tick counter at loop entry** — otherwise a leftover
`.ai/logs/copilot-silent-ticks.txt` from a previous interrupted run can
cause the new run to exit after a single silent tick instead of two:

```bash
echo 0 > .ai/logs/copilot-silent-ticks.txt
```

Use the `loop` skill with a 270-second interval (under the 5-minute prompt-cache
TTL — see Anthropic prompt cache docs; 300 s would burn the cache every tick).
The loop body is the steps below.

**Loop body (each tick):**

1. **Fetch new Copilot comments since cutoff.**

   **Required guards** — abort the tick (not the loop) on:
   - Missing `copilot-cutoff.txt` (without this the jq comparison `> ""` would
     match every Copilot comment ever made on the PR, causing replay).
   - Failed `gh api` (rate limit, network) — `jq 'length'` on a truncated or
     error body returns `0` and would be indistinguishable from a silent tick,
     causing a false SUCCESS exit. **API failures must NEVER touch the silent-tick counter.**

   ```bash
   PR_NR=$(cat .ai/logs/current-pr.txt)
   OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

   if [ ! -s .ai/logs/copilot-cutoff.txt ]; then
     echo "ERROR: copilot-cutoff.txt missing or empty — refusing to poll without it."
     echo "This usually means step 4 did not complete. Re-run /ship-and-watch from step 1."
     exit 1
   fi
   CUTOFF=$(cat .ai/logs/copilot-cutoff.txt)

   # Inline PR comments from Copilot
   if ! gh api "repos/$OWNER_REPO/pulls/$PR_NR/comments" \
        --jq "[.[] | select(.user.login | test(\"copilot\"; \"i\")) | select(.created_at > \"$CUTOFF\")]" \
        > .ai/logs/copilot-inline.json 2>.ai/logs/copilot-inline.err; then
     echo "WARN: gh api /comments failed this tick — skipping. stderr: $(cat .ai/logs/copilot-inline.err)"
     # Skip this tick WITHOUT incrementing silent counter (do not exit loop).
     continue
   fi

   # Top-level review summaries from Copilot
   if ! gh api "repos/$OWNER_REPO/pulls/$PR_NR/reviews" \
        --jq "[.[] | select(.user.login | test(\"copilot\"; \"i\")) | select(.submitted_at > \"$CUTOFF\")]" \
        > .ai/logs/copilot-reviews.json 2>.ai/logs/copilot-reviews.err; then
     echo "WARN: gh api /reviews failed this tick — skipping. stderr: $(cat .ai/logs/copilot-reviews.err)"
     continue
   fi

   # Defensive: only valid JSON arrays reach the counters.
   if ! INLINE_COUNT=$(jq 'length' .ai/logs/copilot-inline.json 2>/dev/null); then
     echo "WARN: copilot-inline.json is not a valid JSON array — skipping tick."
     continue
   fi
   if ! REVIEW_COUNT=$(jq 'length' .ai/logs/copilot-reviews.json 2>/dev/null); then
     echo "WARN: copilot-reviews.json is not a valid JSON array — skipping tick."
     continue
   fi
   ```

   The `continue` statements above assume the loop body runs inside a `while`
   or `for` construct provided by the `loop` skill. If the skill instead
   re-invokes the loop body as a fresh shell each tick, replace `continue`
   with `exit 0` (skip this tick, wait for next) — the **critical invariant**
   is: on API failure, do NOT touch the silent-tick counter.

2. **Decide branch — explicit silent-tick counter protocol:**

   The counter lives in `.ai/logs/copilot-silent-ticks.txt`. It is
   initialized to `0` when the loop is first entered (step 5 entry).
   On every tick, do exactly this:

   ```bash
   SILENT_TICKS=$(cat .ai/logs/copilot-silent-ticks.txt 2>/dev/null || echo 0)

   if [ "$INLINE_COUNT" -eq 0 ] && [ "$REVIEW_COUNT" -eq 0 ]; then
     # Silent tick
     SILENT_TICKS=$((SILENT_TICKS + 1))
     echo "$SILENT_TICKS" > .ai/logs/copilot-silent-ticks.txt
     if [ "$SILENT_TICKS" -ge 2 ]; then
       echo "Copilot silent for 2 consecutive ticks — exiting loop with SUCCESS"
       exit 0
     fi
     # else: continue to next tick
   else
     # Activity detected — reset and address (step 6)
     echo 0 > .ai/logs/copilot-silent-ticks.txt
     # ... proceed to step 6
   fi
   ```

   **Rule of thumb:** Read counter at tick start, increment-and-persist
   on silence, reset-and-persist on activity. The counter is the sole
   source of truth for "are we done yet" — do not infer from anything
   else.

3. **Cap iterations:** if the loop has run more than **6 ticks total** (~27 min)
   OR more than **4 fix-rounds** (rounds where new comments were addressed),
   STOP and escalate to `needs-human` (graded — see `implement-issue.md`).
   Write status to `.ai/logs/ship-and-watch.md`.

### 6. Address Copilot comments

Inline comments and review summaries are **different GitHub objects** with
**different reply mechanisms** — do not treat them as one stream:

| Source file | GitHub object | Has file/line? | Reply via |
|---|---|---|---|
| `.ai/logs/copilot-inline.json` | pull request review comment | Yes (`path`, `line`/`original_line`) | `POST /repos/{r}/pulls/{nr}/comments/{id}/replies` |
| `.ai/logs/copilot-reviews.json` | pull request review (top-level summary) | No | `POST /repos/{r}/issues/{nr}/comments` (top-level PR comment), referencing the review |

**6a. For each inline comment in `.ai/logs/copilot-inline.json`:**

1. Read body, `path`, `line` (or `original_line` if the line moved), severity.
2. Verify against current code with Read on the cited file/line — it may be
   stale from a previous iteration.
3. Categorize:
   - **Valid blocker** → fix with Edit.
   - **Valid nit** → fix if cheap (<5 min), otherwise defer with reply.
   - **False positive / stale** → reply on the comment thread:
     ```bash
     gh api -X POST "repos/$OWNER_REPO/pulls/$PR_NR/comments/<comment_id>/replies" \
       --field body="Not changing because <reason>."
     ```

**6b. For each review summary in `.ai/logs/copilot-reviews.json`:**

Review summaries cover the PR as a whole and have no `path`/`line`. The
inline-replies endpoint will 404 for review IDs — do not use it.

1. Read `body` and `state` (`COMMENTED`, `CHANGES_REQUESTED`, `APPROVED`).
   `APPROVED` with empty `body` is informational only — no action needed.
2. Treat each bullet/paragraph in the body as a separate finding and
   categorize per the rules in 6a.
3. To reply or defer, post a **top-level PR comment** referencing the review:
   ```bash
   gh api -X POST "repos/$OWNER_REPO/issues/$PR_NR/comments" \
     --field body="Re: review #<review_id> — <reason or summary of fixes>."
   ```
   (`/issues/{nr}/comments` is the same endpoint `gh pr comment` uses; PRs
   are issues for the purposes of top-level comments.)

**6c. After handling all findings:**

1. **Run verify again** before pushing. **Hard-stop on failure** — do NOT
   proceed to commit/push if verify exits non-zero. Some loop runtimes
   swallow exit codes; the explicit guard below makes the contract
   independent of runtime behavior:

   ```bash
   if ! bash .ai/scripts/verify.sh; then
     echo "ERROR: verify.sh failed after applying Copilot fixes — STOPPING loop."
     echo "Do not commit. Inspect failures, fix manually, and re-run /ship-and-watch."
     exit 1
   fi
   ```

2. **Commit and push.** Push failure (rebase needed, protected branch,
   network) must also stop the loop — otherwise step 6c.4 would re-request
   review on the previous (unpushed) HEAD and the next tick's silence would
   be a false SUCCESS:

   ```bash
   git add <changed files>   # NEVER git add -A
   git commit -m "fix: address Copilot review batch <N>"
   if ! git push; then
     echo "ERROR: git push failed — STOPPING loop. Resolve the push issue manually."
     exit 1
   fi
   ```

3. **Update cutoff** so the next tick only sees comments from the *next* review round:

   ```bash
   date -u +"%Y-%m-%dT%H:%M:%SZ" > .ai/logs/copilot-cutoff.txt
   ```

4. **Re-request review** so Copilot reviews the fix. Use the GraphQL
   re-request path here (the REST POST is a no-op after the first review):

   ```bash
   PR_ID=$(gh api graphql -f query="query{repository(owner:\"${OWNER_REPO%%/*}\",name:\"${OWNER_REPO##*/}\"){pullRequest(number:$PR_NR){id}}}" --jq '.data.repository.pullRequest.id')
   gh api graphql -f query="mutation{requestReviews(input:{pullRequestId:\"$PR_ID\",botIds:[\"BOT_kgDOCnlnWA\"],union:true}){pullRequest{number}}}"
   ```

### 7. Exit conditions

| Outcome | Action |
|---------|--------|
| Two consecutive silent ticks | SUCCESS — continue per your chosen ordering (internal reviewers next, or report PR merge-ready). |
| Iteration cap hit (6 ticks / 4 fix-rounds) | `needs-human` (graded). Write summary to `.ai/logs/ship-and-watch.md`. |
| verify.sh fails after a fix | STOP loop. Report the failure. Do not push broken code. |
| Manual interrupt | The user can `/clear` or interrupt the loop at any time. State is in `.ai/logs/current-pr.txt`. |

### 8. Cleanup

On exit (either path):

```bash
rm -f .ai/logs/copilot-cutoff.txt .ai/logs/copilot-silent-ticks.txt \
      .ai/logs/copilot-inline.json .ai/logs/copilot-reviews.json \
      .ai/logs/copilot-inline.err .ai/logs/copilot-reviews.err
# keep current-pr.txt — the next step (internal reviewers or merge) needs it
```

---

## Rationale and tradeoffs

- **270 s interval** stays inside the Anthropic prompt cache TTL (5 min).
  Picking 300 s would burn the cache on every tick.
- **GraphQL `requestReviews` with `botIds:["BOT_kgDOCnlnWA"]`** is the reliable
  trigger for both first reviews and re-reviews on free private repos (no Team
  org → no rulesets, no individual auto-toggle on that tier). The REST POST is
  unreliable for the first review and a silent no-op after Copilot has already
  reviewed. Verified empirically in a sister project (PR #137 2026-05-19,
  PR #150 2026-06-02). `gh pr edit --add-reviewer` (any variant) fails because
  the gh CLI cannot resolve the bot user. `gh pr comment "@copilot review"`
  posts but does not wake the bot.
- **Two silent ticks before exit** guards against the race where Copilot
  is still processing the latest push when we poll. One silent tick is
  ambiguous; two is convincing.
- **Cutoff timestamp pattern** prevents re-processing the same comments
  on every tick.
- **Hard cap at 6 ticks / 4 fix-rounds** — if Copilot keeps finding new
  issues that long, the diff is fighting us. Escalate.
- **`.ai/logs/` for state, not `/tmp/`** — Windows-robust and survives
  between ticks regardless of how the loop runtime spawns shells.

## Connection to the workflow

Two valid placements in `.ai/workflows/implement-issue.md` — pick one per project
and be consistent:

1. **Between Step 7 (verify) and Step 8 (internal reviewers):** the external AI
   review runs first; internal reviewers then review a diff that has already
   converged. This automates the "wait for the external reviewer" instruction
   in Step 8.
2. **After Step 10 (finalize):** internal reviewers gate the commit as usual;
   `/ship-and-watch` then runs the external review as the last gate. On SUCCESS
   the PR is ready for the user's merge decision.
